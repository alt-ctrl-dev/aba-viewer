defmodule AbaViewerWeb.AbaLive.Index do
  use AbaViewerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:avatar,
       accept: ~w(.jpg),
       max_entries: 1,
       progress: &handle_progress/3,
       auto_upload: true
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
        :code.get_path()
        dest = Path.join([:code.priv_dir(:aba_viewer), "static", "uploads", Path.basename(path)])
        # The `static/uploads` directory must exist for `File.cp!/2`
        # and MyAppWeb.static_paths/0 should contain uploads to work,.
        File.cp!(path, dest)
        {:ok, ~p"/uploads/#{Path.basename(dest)}"}
      end)

    {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(:too_many_files), do: "You have selected too many files"

  defp handle_progress(:avatar, entry, socket) do
    if entry.done? do
      uploaded_file =
        consume_uploaded_entry(socket, entry, fn %{path: path} = meta ->
          IO.inspect(entry, label: "entry")
          IO.inspect(meta, label: "meta")

          dest =
            Path.join([
              :code.priv_dir(:aba_viewer) |> IO.inspect(label: "priv_dir"),
              "static",
              "uploads",
              Path.basename(path)|> IO.inspect(label: "basename path")
            ])|> IO.inspect(label: "dest")

          File.cp!(path, dest)
          {:ok, ~p"/uploads/#{Path.basename(dest)|> IO.inspect(label: "basename dest")}"}
        end)
        |> IO.inspect(label: "uploaded_file")

      {:noreply, put_flash(socket, :info, "file #{uploaded_file} uploaded")}
    else
      {:noreply, socket}
    end
  end
end
