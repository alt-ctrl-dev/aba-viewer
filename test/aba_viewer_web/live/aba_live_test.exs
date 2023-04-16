defmodule AbaViewerWeb.AbaLiveTest do
  use AbaViewerWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Index" do
    test "lists all validator", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/")

      assert html =~ "Aba Viewer"
      # assert html =~ "This tool will help you quickly identify issues with your ABA file."
      # assert html =~ "Click to upload or drag and drop your ABA file"
    end
  end
end
