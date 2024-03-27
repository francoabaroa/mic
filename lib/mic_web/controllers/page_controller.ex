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
    personalized_resources = get_personalized_resources(conn.assigns.current_user)
    personalized_resources_html = clean_html(personalized_resources)

    render(conn, :my_insights,
      personalized_resources: add_collapsible_list(personalized_resources_html)
    )
  end

  defp get_personalized_resources(user) do
    # TODO: eventually add a for loop to fetch all subjects resources
    # Define the subject you are interested in
    subject = :distribution

    case Mic.Artists.get_resource_by_user_id_and_subject!(user.id, subject) do
      %Mic.Artists.Resource{} = resource ->
        # TODO: Need to define what this map looks like. For now its column content, with a list of maps title content keypair
        resource.content |> List.first() |> Map.get("content")

      _error ->
        # Handle the case where no resource is found or an error occurs
        "No personalized content available. Check back later."
    end
  end

  def add_collapsible_list(content) do
    """
    <button type="button" class="collapsible-list">
    <span class="collapsible-button-content">Distribution
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-unfold-vertical"><path d="M12 22v-6"/><path d="M12 8V2"/><path d="M4 12H2"/><path d="M10 12H8"/><path d="M16 12h-2"/><path d="M22 12h-2"/><path d="m15 19-3 3-3-3"/><path d="m15 5-3-3-3 3"/></svg>
    </span>
    </button>

    <div class="collapsible-content">
      #{content}
    </div>
    """
  end

  def clean_html(html_string) do
    # Remove the specific unwanted prefix
    String.replace(html_string, "```html", "")
    # To ensure any closing tag is also removed if present
    |> String.replace("```", "")
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
