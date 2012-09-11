module Alchemy
  class EssenceText < ActiveRecord::Base

    acts_as_essence

    attr_accessible(
      :do_not_index,
      :body,
      :public,
      :link,
      :link_title,
      :link_class_name,
      :link_target
    )

    # Require acts_as_ferret only if Ferret full text search is enabled (default).
    # You can disable it in +config/alchemy/config.yml+
    if Config.get(:ferret) == true
      require 'acts_as_ferret'
      acts_as_ferret(
        :fields => {
          :body => {:store => :yes}
        },
        :remote => false
      )
      before_save :check_ferret_indexing
    end

  private

    def check_ferret_indexing
      if self.do_not_index
        self.disable_ferret(:always)
      end
    end

  end
end
