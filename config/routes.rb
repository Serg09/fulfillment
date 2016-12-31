Rails.application.routes.draw do
  mount ResqueWeb::Engine => '/resque_web'
  devise_for :users

  namespace :api do
    namespace :v1 do
      resources :products, only: [:index], defaults: {format: :json}
      get 'products/:sku', to: 'products#show', defaults: {format: :json}
      resources :ship_methods, only: [:index], defaults: {format: :json}
      resources :orders, only: [:index, :show, :create, :update], defaults: {format: :json} do
        resources :order_items, only: [:index, :create], path: 'items', defaults: {format: :json}
        resources :payments, only: [:create], defaults: {format: :json}
        member do
          patch :submit, defaults: {format: :json}
        end
      end
      resources :order_items, only: [:update, :destroy], defaults: {format: :json}
      resources :payments, only: [] do
        collection do
          get :token, defaults: {format: :json}
        end
      end
    end
  end

  resources :clients
  resources :orders do
    resources :order_items, only: [:new, :create], path: 'items'
    member do
      patch :submit
      patch :export
    end
  end
  resources :confirmations, only: [:show]
  resources :order_items, only: [:edit, :update, :destroy]
  resources :products
  resources :payments, only: [:index, :show]
  root to: 'pages#welcome'
end
