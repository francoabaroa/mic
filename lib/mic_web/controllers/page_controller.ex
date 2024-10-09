defmodule MicWeb.PageController do
  use MicWeb, :controller

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
    # TODO: what should I do here?
    render(conn, :home)
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

  def podcasts(conn, _params) do
    render(conn, :podcasts)
  end

  def articles(conn, _params) do
    render(conn, :articles)
  end

  def tutorials(conn, _params) do
    render(conn, :tutorials)
  end

  def webinars(conn, _params) do
    render(conn, :webinars)
  end

  def my_insights(conn, _params) do
    resources = get_personalized_resources(conn.assigns.current_user)
    render(conn, :my_insights, personalized_resources: resources, layout: false)
  end

  defp get_personalized_resources(user) do
    subjects = Mic.Types.available_subject_and_assistant_types()

    Enum.map(subjects, fn subject ->
      content =
        case Mic.Artists.get_resource_by_user_id_and_subject!(user.id, subject) do
          %Mic.Artists.Resource{} = resource ->
            resource.content |> List.first() |> Map.get("content") |> clean_html()

          nil ->
            "No personalized content available for #{subject}. Check back later."

          _error ->
            "An error occurred while fetching personalized content for #{subject}."
        end

      formatted_subject =
        subject
        |> to_string()
        |> String.replace("_", " ")
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")

      %{
        subject: formatted_subject,
        content: content
      }
    end)
  end

  defp clean_html(html_string) do
    html_string
    |> String.replace("```html", "")
    |> String.replace("```", "")
    |> String.replace(~r/<([^>]+)>/, "<\\1 class=\"text-white\">")
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
