defmodule TreeOrgWeb.TreeTestLive do
  use TreeOrgWeb, :live_view
  alias TreeOrg.TreeStorage
  require Logger
  require Phoenix.PubSub

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(TreeOrg.PubSub, "tree_updates")
    # Get tree from ETS
    tree = TreeStorage.get_tree()
    version = TreeStorage.get_version()

    socket =
      socket
      |> assign(:tree, tree)
      |> assign(:tree_version, version)
      |> assign(:form_data, %{"name" => "", "role" => "", "reports_to" => ""})
      |> assign(:dropdown_options, extract_paths(tree))
      |> assign(:show_form, false)
      |> assign(:form_error, nil)
      |> assign(:editing_node, nil)
      |> assign(:show_edit_form, false)
      |> assign(:edit_form_data, %{"name" => "", "role" => "", "node_id" => ""})
      |> assign(:debug_info, "Initial mount")

    {:ok, socket}
  end

  def handle_event("toggle_form", _params, socket) do
    {:noreply, socket |> update(:show_form, fn show -> not show end) |> assign(:form_error, nil)}
  end

  def handle_event("update_form", %{"user" => form_data}, socket) do
    {:noreply, assign(socket, :form_data, form_data)}
  end

  # Add user event handler
  def handle_event("add_user", _params, socket) do
    %{form_data: %{"name" => name, "role" => role, "reports_to" => reports_to}} = socket.assigns
    tree = TreeStorage.get_tree()

    Logger.info("Attempting to add user with form_data: #{inspect(socket.assigns.form_data)}")

    # Basic validation
    if reports_to in [nil, "", "--Select--"] or String.trim(name) == "" or String.trim(role) == "" do
      Logger.error("Validation failed: All fields must be filled")
      {:noreply, put_flash(socket, :error, "Please fill in all fields and select a valid 'Reports To' value.")}
    else
      # Create new node
      node_name = "#{role} - #{name}"
      node_id = "node-#{:os.system_time(:millisecond)}"
      new_node = %{id: node_id, name: node_name, children: []}

      # Get the target parent ID (last in the comma-separated path)
      parent_ids = String.split(reports_to, ",")
      target_parent_id = List.last(parent_ids)

      # Debug info
      debug_info = "Adding #{node_name} to parent #{target_parent_id}"
      Logger.info(debug_info)

      # Insert the node
      {updated_tree, success} = insert_child(tree, target_parent_id, new_node)

      if success do
        IO.inspect(updated_tree, label: "Updated Tree")

        # Update tree in ETS and broadcast
        TreeStorage.update_tree(updated_tree)
        # Do NOT update assigns here! Let handle_info/2 do it.
        {:noreply, put_flash(socket, :info, "User added successfully!")}
      else
        Logger.error("Node insertion failed. Parent node with id #{target_parent_id} not found")
        socket = assign(socket, :debug_info, "#{debug_info} - FAILED")
        {:noreply, put_flash(socket, :error, "Failed to find the parent node. Please try again.")}
      end
    end
  end

  # Simple recursive insert that returns {tree, success_boolean}
  # Base case: The current node is the target parent.
# Add the new child to its children list.
defp insert_child(%{id: id, children: children} = node, target_id, new_child) when id == target_id do
  Logger.debug("Found target parent with id #{id}. Adding new child.")
  updated_node = %{node | children: (children || []) ++ [new_child]}
  {updated_node, true}
end

# Recursive step: The target is not this node, so search in its children.
defp insert_child(%{children: children} = node, target_id, new_child) when is_list(children) do
  # We need to track if an update has happened anywhere in the children.
  # We'll use map_reduce to both transform the children list and track success.
  {updated_children, overall_success} =
    Enum.map_reduce(children, false, fn child, success_acc ->
      {updated_child, success} = insert_child(child, target_id, new_child)
      # If this branch was successful, the whole operation is successful.
      {updated_child, success or success_acc}
    end)

  # Return the node with its potentially updated children and the success status.
  {%{node | children: updated_children}, overall_success}
end

# Base case: The node has no children and is not the target.
defp insert_child(node, _target_id, _new_child) do
  {node, false} # Return the node unchanged.
end

  # Handle edit node event
  def handle_event("edit_node", %{"node_id" => node_id}, socket) do
    tree = TreeStorage.get_tree()
    node = find_node_by_id(tree, node_id)

    if node do
      parts = String.split(node.name, " - ", parts: 2)
      {role, name} = case parts do
        [role, name] -> {role, name}
        [single_name] -> {"", single_name}
      end

      edit_form_data = %{"name" => name, "role" => role, "node_id" => node_id}

      socket =
        socket
        |> assign(:editing_node, node)
        |> assign(:edit_form_data, edit_form_data)
        |> assign(:show_edit_form, true)
        |> assign(:form_error, nil)

      {:noreply, socket}
    else
      {:noreply, assign(socket, :form_error, "Node not found")}
    end
  end

  def handle_event("update_node", _params, socket) do
    %{edit_form_data: %{"name" => name, "role" => role, "node_id" => node_id}} = socket.assigns
    tree = TreeStorage.get_tree()

    if String.trim(name) == "" or String.trim(role) == "" do
      socket = assign(socket, :form_error, "Please fill in all fields.")
      {:noreply, socket}
    else
      new_name = "#{role} - #{name}"
      updated_tree = update_node_name(tree, node_id, new_name)

      # Update tree in ETS and broadcast
      TreeStorage.update_tree(updated_tree)
      # Do NOT update assigns here! Let handle_info/2 do it.
      {:noreply, put_flash(socket, :info, "Node updated successfully!")}
    end
  end

  def handle_event("update_edit_form", %{"edit_user" => form_data}, socket) do
    {:noreply, assign(socket, :edit_form_data, form_data)}
  end

  def handle_event("cancel_edit", _params, socket) do
    socket =
      socket
      |> assign(:show_edit_form, false)
      |> assign(:editing_node, nil)
      |> assign(:form_error, nil)

    {:noreply, socket}
  end

  def handle_event("delete_node", %{"node_id" => node_id}, socket) do
    Logger.info("Attempting to delete node with id: #{node_id}")

    tree = TreeStorage.get_tree()
    updated_tree = delete_node(tree, node_id)

    # Update tree in ETS and broadcast
    TreeStorage.update_tree(updated_tree)
    # Do NOT update assigns here! Let handle_info/2 do it.
    {:noreply, put_flash(socket, :info, "Node deleted successfully!")}
  end

  # Add this to handle PubSub updates
  def handle_info(:tree_updated, socket) do
    Logger.info("[LiveView] Received :tree_updated in handle_info")
    # Force a full page reload on the client
    {:noreply, push_navigate(socket, to: socket.assigns[:live_action] && Routes.live_path(socket, socket.assigns[:live_action]) || "/")}
  end

  # Helper functions
  defp find_node_by_id(%{id: id} = node, target_id) when id == target_id, do: node
  defp find_node_by_id(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, fn child ->
      find_node_by_id(child, target_id)
    end)
  end
  defp find_node_by_id(_, _), do: nil

  defp update_node_name(%{id: id} = node, target_id, new_name) when id == target_id do
    %{node | name: new_name}
  end
  defp update_node_name(%{children: children} = node, target_id, new_name) when is_list(children) do
    updated_children = Enum.map(children, fn child ->
      update_node_name(child, target_id, new_name)
    end)
    %{node | children: updated_children}
  end
  defp update_node_name(node, _target_id, _new_name), do: node

  defp delete_node(%{children: children} = node, target_id) when is_list(children) do
    updated_children =
      children
      |> Enum.reject(fn child -> child.id == target_id end)
      |> Enum.map(fn child -> delete_node(child, target_id) end)

    %{node | children: updated_children}
  end
  defp delete_node(node, _target_id), do: node

  defp extract_paths(node, id_path \\ [], name_path \\ []) do
    current_id_path = id_path ++ [node.id]
    current_name_path = name_path ++ [node.name]
    display_path = Enum.join(current_name_path, " > ")
    value_path = Enum.join(current_id_path, ",")
    paths = [%{display: display_path, value: value_path}]
    child_paths = Enum.flat_map(node.children || [], &extract_paths(&1, current_id_path, current_name_path))
    paths ++ child_paths
  end

  def render_tree(assigns) do
    children = assigns[:node].children || []
    n = Enum.count(children)
    x2s =
      if n > 0 do
        Enum.map(1..n, fn i ->
          ((100 / (n + 1)) * i)
        end)
      else
        []
      end
    assigns = assigns
    |> Map.put(:children, children)
    |> Map.put(:x2s, x2s)

    ~H"""
    <div class="flex flex-col items-center relative">
      <div class="relative group">
        <div class="tree-node cursor-pointer px-4 py-4 border border-gray-300 bg-blue-100 text-sm rounded shadow-sm inline-block mb-3">
          <%= @node.name %>
        </div>

        <div class="absolute top-0 right-0 transform translate-x-full -translate-y-1 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex space-x-1">
          <%= if @node.id != "ceo-1" do %>
            <button
              phx-click="edit_node"
              phx-value-node_id={@node.id}
              class="bg-yellow-500 hover:bg-yellow-600 text-white text-xs px-2 py-1 rounded"
              title="Edit"
            >
              ✏️
            </button>
            <button
              phx-click="delete_node"
              phx-value-node_id={@node.id}
              class="bg-red-500 hover:bg-red-600 text-white text-xs px-2 py-1 rounded"
              title="Delete"
              onclick="return confirm('Are you sure you want to delete this node?')"
            >
              🗑️
            </button>
          <% end %>
        </div>
      </div>

      <%= if @children != [] do %>
        <div class="relative w-full flex justify-center items-start" style="height: 40px;">
          <svg width="100%" height="40" style="position: absolute; left: 0; top: 0; pointer-events: none;">
            <%= for {_child, idx} <- Enum.with_index(@children) do %>
              <line
                x1="50%" y1="0"
                x2={to_string(Enum.at(@x2s, idx)) <> "%"}
                y2="40"
                stroke="#a0aec0" stroke-width="2" />
            <% end %>
          </svg>
        </div>
        <div class="flex justify-center space-x-4 relative w-full">
          <%= for child <- @children do %>
            <div class="relative z-10 flex-1 flex justify-center">
              <.render_tree node={child} />
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
