defmodule MicWeb.PageControllerTest do
  use MicWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Incurator"
  end
end
