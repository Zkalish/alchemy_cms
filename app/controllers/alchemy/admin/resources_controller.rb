module Alchemy
  module Admin
    class ResourcesController < Alchemy::Admin::BaseController

      include Alchemy::ResourcesHelper
      helper Alchemy::ResourcesHelper
      helper_method :resource_handler

      before_filter :load_resource, :only => [:show, :edit, :update, :destroy]

      handles_sortable_columns do |c|
        c.default_sort_value = :name
        c.link_class = 'sortable'
        c.indicator_class = {:asc => "sorted asc", :desc => "sorted desc"}
        c.indicator_text = {:asc => "<i>&nbsp;&darr;&nbsp;</i>", :desc => "<i>&nbsp;&uarr;&nbsp;</i>"}
      end

      def index
        if params[:query].present?
          items = queried_items
        else
          items = resource_handler.model
        end
        items = items.page(params[:page] || 1).per(per_page_value_for_screen_size).order(sort_order)
        instance_variable_set("@#{resource_handler.resources_name}", items)
      end

      def new
        instance_variable_set("@#{resource_handler.model_name}", resource_handler.model.new)
        render :layout => !request.xhr?
      end

      def show
        render :layout => !request.xhr?
      end

      def edit
        render :layout => !request.xhr?
      end

      def create
        instance_variable_set("@#{resource_handler.model_name}", resource_handler.model.new(params[resource_handler.namespaced_model_name.to_sym]))
        resource_instance_variable.save
        render_errors_or_redirect(
          resource_instance_variable,
          resources_path,
          flash_notice_for_resource_action
        )
      end

      def update
        resource_instance_variable.update_attributes(params[resource_handler.namespaced_model_name.to_sym])
        render_errors_or_redirect(
          resource_instance_variable,
          resources_path,
          flash_notice_for_resource_action
        )
      end

      def destroy
        resource_instance_variable.destroy
        flash_notice_for_resource_action
      end

      def resource_handler
        @_resource_handler ||= Alchemy::Resource.new(controller_path, alchemy_module)
      end

    protected

      # Returns a translated +flash[:notice]+.
      # The key should look like "Modelname successfully created|updated|destroyed."
      def flash_notice_for_resource_action(action = params[:action])
        return if resource_instance_variable.errors.any?
        case action.to_sym
        when :create
          verb = "created"
        when :update
          verb = "updated"
        when :destroy
          verb = "removed"
        end
        flash[:notice] = _t("#{resource_handler.model_name.classify} successfully #{verb}", :default => _t("Succesfully #{verb}"))
      end

      def is_alchemy_module?
        not alchemy_module.nil? and not alchemy_module['engine_name'].nil?
      end

      def alchemy_module
        @alchemy_module ||= module_definition_for(:controller => params[:controller], :action => 'index')
      end

      def load_resource
        instance_variable_set("@#{resource_handler.model_name}", resource_handler.model.find(params[:id]))
      end

      # Returns a sort order for AR#sort method
      #
      # Falls back to id, if the requested column is not a column of model.
      # Used by handles_sortable_columns
      #
      def sort_order
        sortable_column_order do |column, direction|
          if resource_handler.model.column_names.include?(column.to_s)
            "`#{resource_handler.model.table_name}`.`#{column}` #{direction}"
          else
            "`#{resource_handler.model.table_name}`.`id` #{direction}"
          end
        end
      end

      # Returns an activerecord object that contains items matching params[:query]
      #
      # If the model contains model relations, all associations tables get queried as well.
      #
      def queried_items
        query = params[:query].downcase.split(' ').join('%')
        query = ActiveRecord::Base.sanitize("%#{query}%")
        items = resource_handler.model.where(search_query(query))
        if contains_searchable_relations?
          items = items.includes(*resource_relations_names)
        end
        items
      end

      # Returns a search query string
      #
      # It queries all searchable attributes from resource model via LIKE and joins them via OR.
      #
      # If the attribute is a relation it builds the query for the associated table.
      #
      def search_query(search_terms)
        resource_handler.searchable_attributes.map do |attribute|
          if relation = attribute[:relation]
            "`#{relation[:model_association].klass.table_name}`.`#{relation[:attr_method]}` LIKE #{search_terms}"
          else
            "`#{resource_handler.model.table_name}`.`#{attribute[:name]}` LIKE #{search_terms}"
          end
        end.join(" OR ")
      end

    end
  end
end
