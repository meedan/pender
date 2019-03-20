require 'api_constraints'

Rails.application.routes.draw do
  namespace :api, defaults: { format: 'json' } do
    scope module: :v1, constraints: ApiConstraints.new(version: 1, default: true) do
      get 'about', to: 'base_api#about', constraints: { format: 'json' }
      resources :medias, only: [:index] do
        collection do
          match '/' => 'medias#delete', constraints: { format: 'json' }, via: [:delete, :purge]
          match '/' => 'medias#bulk', constraints: { format: 'json' }, via: [:post]
        end
      end
    end
  end
end
