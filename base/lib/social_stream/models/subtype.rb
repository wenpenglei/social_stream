require 'active_support/concern'

module SocialStream #:nodoc:
  module Models
    # Common methods for models that have a {SocialStream::Models::Supertype}
    module Subtype
      extend ActiveSupport::Concern

      included do
        class << self
          attr_reader :supertype_name, :supertype_options
        end

        belongs_to supertype_name, {
                    :validate  => true,
                    :autosave  => true,
                    :dependent => :destroy
                  }.merge(supertype_options[:belongs] || {})

        class_eval <<-EOS
          def #{ supertype_name }!                                      # def actor!
            #{ supertype_name } ||                                      #   actor ||
              # FIXME: ruby1.9 remove .inspect
              build_#{ supertype_name }(#{ supertype_options[:build].inspect }) #     build_actor(:subject_type => "User")
          end                                                           # end

        EOS

        alias_method :supertype!, "#{ supertype_name }!"

        before_validation :supertype!
      end

      module ClassMethods
        def supertype_foreign_key
          "#{ supertype_name }_id"
        end 
      end

      module InstanceMethods
        # Delegate missing methods to supertype, if they exist there
        def method_missing(method, *args, &block)
          super
        rescue NameError => subtype_error
          # These methods must be raised to avoid loops
          # (the @supertype_name association (i.e. :actor) calls here again)
          exceptions = [ "_#{ self.class.supertype_foreign_key }".to_sym ] # [ :_actor_id ]
          raise subtype_error if exceptions.include?(method)

          begin
            supertype!.__send__ method, *args, &block
          # We rescue supertype's NameErrors so methods not defined are raised from
          # the subtype. Example: user.foo should raise "foo is not defined in user"
          # and not "in actor"
          rescue NameError => supertype_error
            raise subtype_error
          end
        end

        # {SocialStream::Models::Supertype} handles some methods
        def respond_to? *args
          super || supertype!.respond_to?(*args)
        end 
      end

      module ActiveRecord
        extend ActiveSupport::Concern

        module ClassMethods
          # This class is a subtype. Its supertype class is name
          def subtype_of name, options = {}
            @supertype_name = name
            @supertype_options = options
            include SocialStream::Models::Subtype
          end
        end
      end
    end
  end
end
