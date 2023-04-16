defmodule AbaViewerWeb.AbaLiveTest do
  use AbaViewerWeb.ConnCase

  import Phoenix.LiveViewTest

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}



  describe "Index" do

    test "lists all validator", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/")

      assert html =~ "Upload file"
    end
  end
end
