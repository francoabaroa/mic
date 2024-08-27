defmodule MicWeb.Router do
  use MicWeb, :router

  import MicWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MicWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :check_profile do
    plug MicWeb.Plugs.CheckProfile
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MicWeb do
    pipe_through :browser

    # TODO: does this belong here or below?
    get "/", PageController, :home
  end

  scope "/api", MicWeb do
    pipe_through :api

    # TODO: remove or leave
    # TODO: update spotify/instagram config to correct api endpoint
    get "/auth/google/callback", PageController, :oauth_callback
    get "/auth/spotify/callback", AuthController, :spotify_callback
    get "/auth/instagram/callback", AuthController, :instagram_callback

    post "/whatsapp/webhook", WhatsAppController, :receive_message
    get "/whatsapp/webhook", WhatsAppController, :receive_verification
  end

  # Other scopes may use custom stacks.
  # scope "/api", MicWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:mic, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MicWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", MicWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{MicWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", MicWeb do
    pipe_through [:browser, :require_authenticated_user]

    # TODO: make visible without auth
    get "/articles", PageController, :articles
    get "/checklist", PageController, :checklist
    get "/educational-hub", PageController, :educational_hub
    get "/music-funnel", PageController, :funnel
    get "/my-insights", PageController, :my_insights
    get "/podcasts", PageController, :podcasts
    get "/tutorials", PageController, :tutorials
    get "/webinars", PageController, :webinars

    live_session :require_authenticated_user,
      on_mount: [{MicWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email

      # TODO: remove the view for profiles
      # live "/profiles", ProfileLive.Index, :index
      # live "/profiles/new", ProfileLive.Index, :new
      # live "/profiles/:id/edit", ProfileLive.Index, :edit

      # live "/profiles/:id", ProfileLive.Show, :show
      # live "/profiles/:id/show/edit", ProfileLive.Show, :edit

      # # TODO: remove the view
      # live "/messages", MessageLive.Index, :index
      # live "/messages/new", MessageLive.Index, :new
      # live "/messages/:id/edit", MessageLive.Index, :edit

      # live "/messages/:id", MessageLive.Show, :show
      # live "/messages/:id/show/edit", MessageLive.Show, :edit

      # TODO: merge chat and messages
      live "/chat/:scenario_id", ChatLive.Index, :index

      scope "/" do
        pipe_through :check_profile
        live "/onboarding", OnboardingLive.Index, :index
      end

      live "/dashboard", DashboardLive.Index, :index
    end
  end

  scope "/", MicWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{MicWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
