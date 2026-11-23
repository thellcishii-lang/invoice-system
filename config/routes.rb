Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # 公開申込フロー（ログイン不要）と Stripe Webhook、招待用パスワード設定
  resources :signups, only: %i[ new create ] do
    collection do
      post :confirm
      get :complete
    end
  end
  post "stripe/webhooks", to: "stripe_webhooks#create"
  get "password_setup/:token", to: "password_setups#edit", as: :password_setup
  patch "password_setup/:token", to: "password_setups#update"

  root "dashboard#index"
  resource :setting, only: %i[ show update ] do
    post :test_smtp
  end
  resources :clients
  resources :items
  resources :item_categories, only: %i[ new create edit update destroy ]
  resources :documents do
    member do
      get :print
      get :construction_print
      get :envelope
      get :fax_cover
      post :convert
      post :duplicate
      post :save_as_template
    end
    resource :delivery, only: %i[ new create ], controller: "document_deliveries"
    resources :scheduled_deliveries, only: %i[ create ]
    resources :payments, only: %i[ create edit update destroy ]
  end
  resources :recurring_documents, except: %i[ show ]
  resources :unpaid_invoices, only: %i[ index ]
  resources :document_deliveries, only: %i[ index ] do
    member do
      post :resend
    end
  end
  resources :scheduled_deliveries, only: %i[ index ] do
    member do
      post :cancel
    end
  end
  resources :send_templates, except: %i[ show ]
  resources :document_templates, except: %i[ show ]
  resource :report, only: %i[ show ], controller: "reports"
  # リンク共有：署名付きトークンでログインなしに帳票の印刷画面を見せる
  get "public/documents/:token", to: "public_documents#show", as: :public_document
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
