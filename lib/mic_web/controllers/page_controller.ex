defmodule MicWeb.PageController do
  use MicWeb, :controller

  import Phoenix.LiveView.Controller

  defp protect_with_session(conn, _params, fx) do
    case get_session(conn) do
      %{"oauth_google_token" => _token, "oauth_expiration" => expiration} ->
        if DateTime.compare(DateTime.now!("Etc/UTC"), expiration) == :gt do
          oauth_google_url = ElixirAuthGoogle.generate_oauth_url(conn)
          redirect(conn, external: oauth_google_url)
        else
          fx.()
        end

      _ ->
        oauth_google_url = ElixirAuthGoogle.generate_oauth_url(conn)
        redirect(conn, external: oauth_google_url)
    end
  end

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def funnel(conn, _params) do
    render(conn, :funnel)
  end

  def checklist(conn, _params) do
    render(conn, :checklist)
  end

  def educational_hub(conn, _params) do
    render(conn, :educational_hub)
  end

  def oauth_callback(conn, %{"code" => code}) do
    with {:ok, token} <- ElixirAuthGoogle.get_token(code, conn),
         %{access_token: access_token} <- token,
         {:ok, profile} <- ElixirAuthGoogle.get_user_profile(access_token),
         %{email: email} <- profile,
         %{expires_in: expires_in} <- token,
         restrict_email_domains? <-
           Application.get_env(:mic, :restrict_email_domains, false),
         allowed_email_domains <-
           Application.get_env(:mic, :allowed_email_domains, []) do
      cond do
        # restrict_email_domains set, and domain is found
        restrict_email_domains? and
            Enum.find(allowed_email_domains, &String.contains?(email, &1)) == nil ->
          {:error, "email not allowed"}

        true ->
          :ok
      end
      |> case do
        :ok ->
          expiry_datetime = DateTime.add(DateTime.now!("Etc/UTC"), expires_in, :second)

          conn
          |> put_session("oauth_google_token", token)
          |> put_session("oauth_expiration", expiry_datetime)
          |> put_session("google_profile", profile)
          |> redirect(to: "/")

        {:error, msg} ->
          text(conn, "authorization failed: #{msg}")
      end
    else
      err ->
        text(conn, "authorization failed: #{inspect(err)}")
    end
  end
end
