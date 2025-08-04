defmodule TreeOrgWeb.TreeTestLive do
  use TreeOrgWeb, :live_view
  alias TreeOrg.TreeStorage
  require Logger
  require Phoenix.PubSub

  # Position data structure for tree nodes
  defstruct [:node, :x_position, :width, :children, :level]

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(TreeOrg.PubSub, "tree_updates")
    tree = TreeStorage.get_tree()
    version = TreeStorage.get_version()

    socket =
      socket
      |> assign(:tree, tree)
      |> assign(:tree_version, version)
      |> assign(:form_data, %{"name" => "", "role" => "", "reports_to" => ""})
      |> assign(:dropdown_options, extract_paths(tree, [], []))
      |> assign(:show_form, false)
      |> assign(:form_error, nil)
      |> assign(:editing_node, nil)
      |> assign(:show_edit_form, false)
      |> assign(:edit_form_data, %{"name" => "", "role" => "", "node_id" => ""})
      |> assign(:show_group_modal, false)
      |> assign(:group_members, [])
      |> assign(:group_title, "")

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
    tree = TreeStorage.get_tree()

    Logger.info("Attempting to add user with form_data: #{inspect(socket.assigns.form_data)}")

    if String.trim(name) == "" or String.trim(role) == "" do
      Logger.error("Validation failed: Name and role must be filled")
      {:noreply, put_flash(socket, :error, "Please fill in name and role fields.")}
    else
      node_name = "#{role} - #{name}"
      node_id = "node-#{:os.system_time(:millisecond)}"
      new_node = %{id: node_id, name: node_name, children: []}

      if tree == nil do
        Logger.info("Creating first node as root: #{node_name}")
        TreeStorage.update_tree(new_node)
        {:noreply, put_flash(socket, :info, "First user added successfully!")}
      else
        if reports_to in [nil, "", "--Select--"] do
          Logger.error("Validation failed: Must select a valid 'Reports To' value")
          {:noreply, put_flash(socket, :error, "Please select a valid 'Reports To' value.")}
        else
          parent_ids = String.split(reports_to, ",")
          target_parent_id = List.last(parent_ids)

          {updated_tree, success} = insert_child(tree, target_parent_id, new_node)

          if success do
            TreeStorage.update_tree(updated_tree)
            {:noreply, put_flash(socket, :info, "User added successfully!")}
          else
            Logger.error("Node insertion failed. Parent node with id #{target_parent_id} not found")
            {:noreply, put_flash(socket, :error, "Failed to find the parent node. Please try again.")}
          end
        end
      end
    end
  end

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
    %{:edit_form_data => %{"name" => name, "role" => role, "node_id" => node_id}} = socket.assigns
    tree = TreeStorage.get_tree()

    if String.trim(name) == "" or String.trim(role) == "" do
      socket = assign(socket, :form_error, "Please fill in all fields.")
      {:noreply, socket}
    else
      new_name = "#{role} - #{name}"
      updated_tree = update_node_name(tree, node_id, new_name)

      TreeStorage.update_tree(updated_tree)
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

    TreeStorage.update_tree(updated_tree)
    {:noreply, put_flash(socket, :info, "Node deleted successfully!")}
  end

  def handle_event("show_group_members", %{"group_id" => group_id}, socket) do
    Logger.info("show_group_members event triggered with group_id: #{group_id}")

    # Find the parent node that contains the group
    parent_node = find_parent_of_group(socket.assigns.tree, group_id)

    if parent_node do
      # Now, find the actual group node within the parent's children
      {_leaf_nodes, non_leaf_nodes} = group_leaf_nodes(parent_node.children)
      {leaf_nodes, _non_leaf_nodes} = group_leaf_nodes(parent_node.children)
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

  def handle_info(:tree_updated, socket) do
    Logger.info("[LiveView] Received :tree_updated in handle_info")
    tree = TreeStorage.get_tree()
    version = TreeStorage.get_version()
    {:noreply, socket |> assign(:tree, tree) |> assign(:tree_version, version)}
  end

  defp insert_child(%{id: id, children: children} = node, target_id, new_child) when id == target_id do
    Logger.debug("Found target parent with id #{id}. Adding new child.")
    updated_node = %{node | children: (children || []) ++ [new_child]}
    {updated_node, true}
  end

  defp insert_child(%{children: children} = node, target_id, new_child) when is_list(children) do
    {updated_children, overall_success} =
      Enum.map_reduce(children, false, fn child, success_acc ->
        {updated_child, success} = insert_child(child, target_id, new_child)
        {updated_child, success or success_acc}
      end)

    {%{node | children: updated_children}, overall_success}
  end

  defp insert_child(node, _target_id, _new_child) do
    {node, false}
  end

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

  defp extract_paths(nil, _id_path, _name_path), do: []
  defp extract_paths(node, id_path, name_path) do
    current_id_path = id_path ++ [node.id]
    current_name_path = name_path ++ [node.name]
    display_path = Enum.join(current_name_path, " > ")
    value_path = Enum.join(current_id_path, ",")
    paths = [%{display: display_path, value: value_path}]
    child_paths = Enum.flat_map(node.children || [], &extract_paths(&1, current_id_path, current_name_path))
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

  defp is_leaf?(%{children: children}) when is_list(children), do: Enum.empty?(children)
  defp is_leaf?(_), do: true

  defp group_leaf_nodes(children) do
    {leaf_nodes, non_leaf_nodes} = Enum.split_with(children, &is_leaf?/1)

    if length(leaf_nodes) > 3 do
      group_id = "leaf-group-#{hd(leaf_nodes).parent_id}"
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

  defp find_parent_of_group(node, group_id) do
    # Check if the current node is the parent of the group.
    {leaf_nodes, _non_leaf_nodes} = Enum.split_with(node.children || [], &is_leaf?/1)
    if length(leaf_nodes) > 3 do
      # Construct a group_id that is consistent and dependent on the parent.
      # Assuming parent_id is available in the leaf nodes.
      parent_id = hd(leaf_nodes).parent_id
      expected_group_id = "leaf-group-#{parent_id}"
      if expected_group_id == group_id do
        node
      end
    end

    # Recursively search in the children of the current node.
    Enum.find_value(node.children || [], fn child ->
      find_parent_of_group(child, group_id)
    end)
  end

  # Calculate bottom-up positioning for the entire tree
  defp calculate_tree_positions(node, level \\ 0) do
    children = node.children || []
    {leaf_nodes, non_leaf_nodes} = group_leaf_nodes(children)
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

      # Position children relative to their parent's center
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
