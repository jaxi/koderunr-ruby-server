Rails.application.routes.draw do
  root to: 'page#index'

  namespace :api do
    post "/register", to: "code#register"
    get "/run", to: "code#run"
    post "/stdin", to: "code#stdin"
    post "/save", to: "code#save"
    get "/fetch", to: "code#fetch"
  end
end
