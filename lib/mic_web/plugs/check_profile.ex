defmodule MicWeb.Plugs.CheckProfile do
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  alias Mic.Artists

  def init(default), do: default

  def call(conn, _opts) do
    Logger.info("Plug getting called before")

    user_id = conn.assigns[:current_user] && conn.assigns[:current_user].id
    Logger.info("Plug getting called")
    Logger.info("User ID: #{user_id}")

    if user_id && Artists.get_profile_by_user_id!(user_id) do
      Logger.info("Plug getting called after")

      conn
      |> redirect(to: "/")
      |> halt()
    else
      conn
    end
  end
end
