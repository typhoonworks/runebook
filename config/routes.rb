Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  resources :notebooks, only: [ :index, :update ] do
    collection do
      scope module: :notebooks do
        resources :files, only: [ :index, :create ]
        resources :directories, only: [ :create ]
        resources :imports, only: [ :create ]
      end
    end
  end

  resources :sessions, only: [ :create, :show, :destroy ] do
    scope module: :sessions do
      resource :save, only: [ :create ]
      resource :autosave, only: [ :create ]
      resources :files, only: [ :index ]
      resources :directories, only: [ :create ]
    end
  end

  post "/markdown/preview" => "markdowns#preview", as: :markdown_preview
  post "/ruby/evaluate" => "ruby_cells#evaluate", as: :ruby_evaluate
end
