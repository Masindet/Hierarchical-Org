defmodule TreeOrgWeb.TreeTestLive do
  use TreeOrgWeb, :live_view
  alias TreeOrg.TreeStorage
  require Logger
  require Phoenix.PubSub

  # Position data structure for tree nodes
  defstruct [:node, :x_position, :width, :children, :level]

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(TreeOrg.PubSub, "tree_updates")

    tree = TreeStorage.get_root_node()

    socket =
      socket
      |> assign(:tree, tree)
      |> assign(:form_data, %{"name" => "", "role" => "", "reports_to" => ""})
      |> assign(:dropdown_options, extract_paths(tree))
      |> assign(:show_form, false)
      |> assign(:form_error, nil)
      |> assign(:editing_node, nil)
      |> assign(:show_edit_form, false)
      |> assign(:edit_form_data, %{"name" => "", "role" => "", "node_id" => ""})
      |> assign(:show_group_modal, false)
      |> assign(:group_members, [])
      |> assign(:group_title, "")
      |> assign(:tree_version, 1)

    {:ok, socket}
  end

  def handle_event("toggle_form", _params, socket) do
    {:noreply, socket |> update(:show_form, fn show -> not show end) |> assign(:form_error, nil)}
  end

  def handle_event("update_form", %{"user" => form_data}, socket) do
    {:noreply, assign(socket, :form_data, form_data)}
  end

  def handle_event("add_user", _params, socket) do
    form_data = socket.assigns.form_data
    name = Map.get(form_data, "name", "")
    role = Map.get(form_data, "role", "")
    reports_to = Map.get(form_data, "reports_to", nil)

    if String.trim(name) == "" or String.trim(role) == "" do
      {:noreply, put_flash(socket, :error, "Please fill in name and role fields.")}
    else
      node_name = "#{role} - #{name}"
      parent_id = if reports_to in [nil, "", "--Select--"], do: nil, else: reports_to

      case TreeStorage.add_node(node_name, parent_id) do
        {:ok, _} ->
          broadcast_tree_update()
          {:noreply,
           socket
           |> put_flash(:info, "User added successfully!")
           |> assign(:show_form, false)
           |> assign(:form_data, %{"name" => "", "role" => "", "reports_to" => ""})}
        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to add user. Errors: #{inspect(changeset.errors)}")}
      end
    end
  end

  def handle_event("edit_node", %{"node_id" => node_id}, socket) do
    node = TreeStorage.get_node(node_id)

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
        |> assign(:show_group_modal, false)
        |> assign(:form_error, nil)

      {:noreply, socket}
    else
      {:noreply, assign(socket, :form_error, "Node not found")}
    end
  end

  def handle_event("update_node", _params, socket) do
    %{:edit_form_data => %{"name" => name, "role" => role, "node_id" => node_id}} = socket.assigns

    if String.trim(name) == "" or String.trim(role) == "" do
      socket = assign(socket, :form_error, "Please fill in all fields.")
      {:noreply, socket}
    else
      new_name = "#{role} - #{name}"
      case TreeStorage.update_node(node_id, %{name: new_name}) do
        {:ok, _} ->
          broadcast_tree_update()
          {:noreply,
           socket
           |> put_flash(:info, "Node updated successfully!")
           |> assign(:show_edit_form, false)
           |> assign(:editing_node, nil)}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update node.")}
      end
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
    children = TreeStorage.get_children(node_id)
    if Enum.any?(children) do
      {:noreply, put_flash(socket, :error, "Cannot delete a node with children. Please delete the children first.")}
    else
      Logger.info("Attempting to delete node with id: #{node_id}")

      case TreeStorage.delete_node(node_id) do
        :ok ->
          broadcast_tree_update()
          {:noreply, put_flash(socket, :info, "Node deleted successfully!")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete node.")}
      end
    end
  end

  def handle_event("show_group_members", %{"group_id" => group_id}, socket) do
    Logger.info("show_group_members event triggered with group_id: #{group_id}")

    # Find the parent node that contains the group
    parent_node = find_parent_of_group(socket.assigns.tree, group_id)

    if parent_node do
      # Now, find the actual group node within the parent's children
      children = TreeStorage.get_children(parent_node.id)
      {_leaf_nodes, non_leaf_nodes} = group_leaf_nodes(children, parent_node.id)
      {leaf_nodes, _non_leaf_nodes} = group_leaf_nodes(children, parent_node.id)
      all_children = leaf_nodes ++ non_leaf_nodes
      group_node = Enum.find(all_children, fn child -> Map.get(child, :id) == group_id end)

      if group_node do
        group_members = group_node.children || []
        group_title = group_node.name || "Team Members"

        socket =
          socket
          |> assign(:show_group_modal, true)
          |> assign(:group_members, group_members)
          |> assign(:group_title, group_title)

        {:noreply, socket}
      else
        {:noreply, put_flash(socket, :error, "Group not found inside the parent.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Parent of group not found.")}
    end
  end

  def handle_event("close_group_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_group_modal, false)
      |> assign(:group_members, [])
      |> assign(:group_title, "")
    {:noreply, socket}
  end

  defp broadcast_tree_update() do
    Phoenix.PubSub.broadcast(TreeOrg.PubSub, "tree_updates", :tree_updated)
  end

  def handle_info(:tree_updated, socket) do
    Logger.info("[LiveView] Received :tree_updated in handle_info")
    tree = TreeStorage.get_root_node()
    {:noreply,
     socket
     |> assign(:tree, tree)
     |> assign(:dropdown_options, extract_paths(tree))
     |> assign(:show_group_modal, false)
     |> update(:tree_version, &(&1 + 1))}
  end

  defp extract_paths(nil), do: []
  defp extract_paths(node) do
    do_extract_paths(node, [], [])
  end

  defp do_extract_paths(nil, _, _), do: []
  defp do_extract_paths(node, id_path, name_path) do
    current_id_path = id_path ++ [node.id]
    current_name_path = name_path ++ [node.name]
    display_path = Enum.join(current_name_path, " > ")
    value_path = node.id
    paths = [%{display: display_path, value: value_path}]

    children = TreeStorage.get_children(node.id)
    child_paths = Enum.flat_map(children, &do_extract_paths(&1, current_id_path, current_name_path))
    paths ++ child_paths
  end

  def get_avatar_color(node_id) do
    colors = [
      "bg-blue-500", "bg-green-500", "bg-purple-500", "bg-pink-500", "bg-indigo-500",
      "bg-red-500", "bg-yellow-500", "bg-teal-500", "bg-orange-500", "bg-cyan-500",
      "bg-lime-500", "bg-rose-500", "bg-emerald-500", "bg-violet-500", "bg-amber-500", "bg-sky-500"
    ]

    hash = :erlang.phash2(node_id, length(colors))
    Enum.at(colors, hash)
  end

  defp is_leaf?(node) do
    Enum.empty?(TreeStorage.get_children(node.id))
  end

  # Fixed group_leaf_nodes function - now takes parent_id as parameter
  defp group_leaf_nodes(children, parent_id) do
    {leaf_nodes, non_leaf_nodes} = Enum.split_with(children, &is_leaf?/1)

    if length(leaf_nodes) > 3 do
      group_id = "leaf-group-#{parent_id}"
      grouped_node = %{
        id: group_id,
        name: "Team Members (#{length(leaf_nodes)})",
        children: leaf_nodes,
        is_group: true
      }
      {[grouped_node], non_leaf_nodes}
    else
      {leaf_nodes, non_leaf_nodes}
    end
  end

  defp find_parent_of_group(nil, _), do: nil
  defp find_parent_of_group(node, group_id) do
    children = TreeStorage.get_children(node.id)
    {leaf_nodes, _non_leaf_nodes} = Enum.split_with(children, &is_leaf?/1)
    expected_group_id = "leaf-group-#{node.id}"

    if length(leaf_nodes) > 3 && expected_group_id == group_id do
      node
    else
      Enum.find_value(children, fn child ->
        find_parent_of_group(child, group_id)
      end)
    end
  end

  # Calculate bottom-up positioning for the entire tree
  defp calculate_tree_positions(nil, _level), do: nil
  defp calculate_tree_positions(node, level \\ 0) do
    children = TreeStorage.get_children(node.id)
    {leaf_nodes, non_leaf_nodes} = group_leaf_nodes(children, node.id)
    all_children = leaf_nodes ++ non_leaf_nodes

    if Enum.empty?(all_children) do
      # Leaf node - minimal width
      %__MODULE__{
        node: node,
        x_position: 0,
        width: 300,  # Base width for leaf nodes
        children: [],
        level: level
      }
    else
      # Calculate positions for children first (bottom-up)
      child_positions = Enum.map(all_children, &calculate_tree_positions(&1, level + 1))

      # Calculate total width needed for all children
      min_spacing = 50  # Minimum gap between nodes
      total_children_width = Enum.reduce(child_positions, 0, fn child, acc ->
        acc + child.width
      end)

      # Add spacing between children
      spacing_width = (length(child_positions) - 1) * min_spacing
      required_width = max(300, total_children_width + spacing_width)

      # Position children relative to their parent\'s center
      {positioned_children, _} = Enum.map_reduce(child_positions, -required_width / 2, fn child, current_x ->
        positioned_child = %{child | x_position: current_x + child.width / 2}
        {positioned_child, current_x + child.width + min_spacing}
      end)

      %__MODULE__{
        node: node,
        x_position: 0,  # Parent is always centered
        width: required_width,
        children: positioned_children,
        level: level
      }
    end
  end

  # Collect all nodes with their final positions for rendering
  defp collect_positioned_nodes(nil), do: []
  defp collect_positioned_nodes(tree_pos, offset_x \\ 0) do
    current_node = %{
      node: tree_pos.node,
      x: offset_x + tree_pos.x_position,
      level: tree_pos.level
    }

    child_nodes = Enum.flat_map(tree_pos.children, fn child ->
      collect_positioned_nodes(child, offset_x + tree_pos.x_position)
    end)

    [current_node | child_nodes]
  end

  # Generate SVG lines connecting parent to children
  defp generate_connection_lines(nil), do: []
  defp generate_connection_lines(tree_pos, offset_x \\ 0, parent_x \\ nil, parent_level \\ nil) do
    current_x = offset_x + tree_pos.x_position
    current_level = tree_pos.level

    # Lines from parent to current node (if not root)
    parent_lines = if parent_x && parent_level do
      parent_y = parent_level * 150 + 75  # 150px per level + node center offset
      current_y = current_level * 150 + 75

      [{parent_x, parent_y, current_x, current_y}]
    else
      []
    end

    # Lines from current node to children
    child_lines = Enum.flat_map(tree_pos.children, fn child ->
      generate_connection_lines(child, offset_x + tree_pos.x_position, current_x, current_level)
    end)

    parent_lines ++ child_lines
  end

  def render_tree(assigns) do
    # Calculate positions using bottom-up algorithm
    tree_positions = calculate_tree_positions(assigns[:node])

    # Collect all positioned nodes
    positioned_nodes = collect_positioned_nodes(tree_positions)

    # Generate connection lines
    connection_lines = generate_connection_lines(tree_positions)

    # Calculate bounds for the SVG container
    min_x = if Enum.empty?(positioned_nodes) do
      0
    else
      Enum.min_by(positioned_nodes, & &1.x).x - 150
    end

    max_x = if Enum.empty?(positioned_nodes) do
      300
    else
      Enum.max_by(positioned_nodes, & &1.x).x + 150
    end

    max_level = if Enum.empty?(positioned_nodes) do
      0
    else
      Enum.max_by(positioned_nodes, & &1.level).level
    end

    container_width = max_x - min_x + 300
    container_height = (max_level + 1) * 150 + 100

    # Group nodes by level for easier rendering
    nodes_by_level = Enum.group_by(positioned_nodes, & &1.level)

    assigns = assigns
    |> Map.put(:positioned_nodes, positioned_nodes)
    |> Map.put(:connection_lines, connection_lines)
    |> Map.put(:container_width, container_width)
    |> Map.put(:container_height, container_height)
    |> Map.put(:min_x, min_x)
    |> Map.put(:nodes_by_level, nodes_by_level)
    |> Map.put(:max_level, max_level)

    ~H"""
    <div class="flex flex-col items-center relative w-full overflow-x-auto">
      <div class="relative" style={"width: #{@container_width}px; height: #{@container_height}px;"}>
        <!-- SVG for connection lines -->
        <svg
          class="absolute top-0 left-0 pointer-events-none z-10"
          width={@container_width}
          height={@container_height}
        >
          <%= for {x1, y1, x2, y2} <- @connection_lines do %>
            <line
              x1={x1 - @min_x + 150}
              y1={y1}
              x2={x2 - @min_x + 150}
              y2={y2}
              stroke="#6366f1"
              stroke-width="3"
              opacity="0.7"
            />
          <% end %>
        </svg>

        <!-- Render nodes at their calculated positions -->
        <%= for {level, nodes} <- @nodes_by_level do %>
          <%= for positioned_node <- nodes do %>
            <div
              class="absolute z-20"
              style={"left: #{positioned_node.x - @min_x + 150}px; top: #{level * 150}px; transform: translateX(-50%);"}
            >
              <%= if Map.get(positioned_node.node, :is_group, false) do %>
                <div class="flex flex-col items-center relative">
                  <div class="relative group">
                    <button
                      phx-click="show_group_members"
                      phx-value-group_id={positioned_node.node.id}
                      class="tree-node cursor-pointer px-8 py-6 border-2 border-green-200 bg-gradient-to-br from-green-50 to-green-100 hover:from-green-100 hover:to-green-150 text-base rounded-xl shadow-lg hover:shadow-xl transition-all duration-300 inline-block flex items-center space-x-4 min-w-[280px]"
                    >
                      <div class="w-14 h-14 rounded-full flex items-center justify-center text-white font-bold text-xl bg-green-500 shadow-md">
                        👥
                      </div>
                      <div class="flex-1">
                        <div class="font-semibold text-gray-800 text-lg"><%= positioned_node.node.name %></div>
                        <div class="text-sm text-gray-600">Click to view members</div>
                      </div>
                    </button>
                  </div>
                </div>
              <% else %>
                <div class="relative group">
                  <div class="tree-node cursor-pointer px-8 py-6 border-2 border-gray-200 bg-gradient-to-br from-blue-50 to-blue-100 hover:from-blue-100 hover:to-blue-150 text-base rounded-xl shadow-lg hover:shadow-xl transition-all duration-300 inline-block flex items-center space-x-4 min-w-[280px]">
                    <div class={"w-14 h-14 rounded-full flex items-center justify-center text-white font-bold text-xl shadow-md #{get_avatar_color(positioned_node.node.id)}"}>
                      <%= String.first(positioned_node.node.name) |> String.upcase() %>
                    </div>
                    <div class="flex-1">
                      <div class="font-semibold text-gray-800 text-lg"><%= positioned_node.node.name %></div>
                    </div>
                  </div>

                  <div class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex space-x-2">
                    <%= if positioned_node.node.id != "ceo-1" do %>
                      <button
                        phx-click="edit_node"
                        phx-value-node_id={positioned_node.node.id}
                        class="bg-amber-500 hover:bg-amber-600 text-white text-sm px-3 py-2 rounded-full shadow-md transition-colors duration-200"
                        title="Edit"
                      >
                        ✏️
                      </button>
                      <button
                        phx-click="delete_node"
                        phx-value-node_id={positioned_node.node.id}
                        class="bg-red-500 hover:bg-red-600 text-white text-sm px-3 py-2 rounded-full shadow-md transition-colors duration-200"
                        title="Delete"
                        onclick="return confirm('Are you sure you want to delete this node?')"
                      >
                        🗑️
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
