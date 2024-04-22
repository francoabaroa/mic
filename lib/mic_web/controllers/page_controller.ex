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

    render(conn, :my_insights,
      personalized_resources: add_collapsible_list(personalized_resources)
    )
  end

  defp get_personalized_resources(user) do
    subjects = Mic.Types.available_subject_and_assistant_types()

    personalized_resources =
      Enum.map(subjects, fn subject ->
        case Mic.Artists.get_resource_by_user_id_and_subject!(user.id, subject) do
          %Mic.Artists.Resource{} = resource ->
            %{
              subject: subject,
              content: resource.content |> List.first() |> Map.get("content")
            }

          nil ->
            %{
              subject: subject,
              content: "No personalized content available for #{subject}. Check back later."
            }

          _error ->
            %{
              subject: subject,
              content: "An error occurred while fetching personalized content for #{subject}."
            }
        end
      end)

    personalized_resources
  end

  def add_collapsible_list(personalized_resources) do
    Enum.map(personalized_resources, fn %{subject: subject, content: content} ->
      cleaned_content =
        content
        |> clean_html

      """
      <button type="button" class="collapsible-list">
      <span class="collapsible-button-content">#{if String.contains?(to_string(subject), "_") do
        String.split(to_string(subject), "_") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
      else
        String.capitalize(to_string(subject))
      end}
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-unfold-vertical"><path d="M12 22v-6"/><path d="M12 8V2"/><path d="M4 12H2"/><path d="M10 12H8"/><path d="M16 12h-2"/><path d="M22 12h-2"/><path d="m15 19-3 3-3-3"/><path d="m15 5-3-3-3 3"/></svg>
      </span>
      </button>

      <div class="collapsible-content">
        #{cleaned_content}
      </div>
      """
    end)
    |> Enum.join("\n")
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
