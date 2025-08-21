defmodule TreeOrgWeb.TreeTestLive do
  use TreeOrgWeb, :live_view
  alias TreeOrg.TreeStorage
  alias TreeOrg.TreeNode
  require Logger
  require Phoenix.PubSub

  # Position data structure for tree nodes
  defstruct [:node, :x_position, :width, :children, :level]

  def mount(_params, _session, socket) do
    Logger.info("[LiveView] Mounting TreeTestLive")

    # Always ensure table exists and load data
    TreeStorage.ensure_table_exists()

    if connected?(socket), do: Phoenix.PubSub.subscribe(TreeOrg.PubSub, "tree_updates")

    tree = TreeStorage.get_root_node()
    Logger.info("[LiveView] Initial tree loaded: #{if tree, do: "present", else: "nil"}")

    socket =
      socket
      |> assign(:tree, tree)
      |> assign(:form_data, %{"name" => "", "role" => "", "reports_to" => ""})
      |> assign(:dropdown_options, extract_paths(tree))
      |> assign(:show_form, false)
        |> assign(:show_add_person_modal, false)
      |> assign(:form_error, nil)
        |> assign(:editing_node, nil)
        |> assign(:show_edit_form, false)
        |> assign(:show_edit_person_modal, false)
        |> assign(:show_edit_group_modal, false)
        |> assign(:edit_group_data, %{"name" => "", "node_id" => ""})
        |> assign(:show_add_group_modal, false)
      |> assign(:edit_form_data, %{"name" => "", "role" => "", "node_id" => ""})
      |> assign(:show_group_modal, false)
      |> assign(:group_members, [])
      |> assign(:group_title, "")
      |> assign(:current_group_id, nil)
      |> assign(:add_group_parent_id, nil)
      |> assign(:add_group_name, "")
        |> assign(:search_query, "")
        |> assign(:search_results, [])
        |> assign(:show_search_results, false)
        |> assign(:highlight_person_id, nil)
      |> assign(:tree_version, 1)
      |> assign(:node_to_delete, nil)

    {:ok, socket}
  end

  def handle_event("toggle_form", _params, socket) do
    Logger.info("[LiveView] Toggle form event")
    {:noreply, socket |> update(:show_form, fn show -> not show end) |> assign(:form_error, nil)}
  end

  def handle_event("update_form", %{"user" => form_data}, socket) do
    new_form_data = Map.merge(socket.assigns.form_data, form_data)
    {:noreply, assign(socket, :form_data, new_form_data)}
  end

  def handle_event("add_user", _params, socket) do
    Logger.info("[LiveView] Add user event triggered")
    form_data = socket.assigns.form_data
    name = Map.get(form_data, "name", "")
    role = Map.get(form_data, "role", "")
    reports_to = Map.get(form_data, "reports_to", nil)

    Logger.info("[LiveView] Form data: name=#{name}, role=#{role}, reports_to=#{inspect(reports_to)}")

    if String.trim(name) == "" or String.trim(role) == "" do
      {:noreply, put_flash(socket, :error, "Please fill in name and role fields.")}
    else
      node_name = "#{role} - #{name}"
      parent_id = if reports_to in [nil, "", "--Select--"], do: nil, else: reports_to

      Logger.info("[LiveView] Adding node: #{node_name} with parent_id: #{inspect(parent_id)}")

      # If parent_id is nil, this is a root node, which should be a group.
      # Otherwise, it's a person (leaf node) being added to a group.
      is_group = is_nil(parent_id)

      case TreeStorage.add_node(node_name, parent_id, is_group) do
        {:ok, new_node} ->
          Logger.info("[LiveView] Node added successfully: #{inspect(TreeNode.safe_inspect(new_node))}")

          # Force a complete refresh of the tree data using the new function
          TreeStorage.force_refresh_tree()
          tree = TreeStorage.get_root_node()
          dropdown_options = extract_paths(tree)

          # Increment tree version to force complete re-render
          new_tree_version = socket.assigns.tree_version + 1

          # Push event to trigger page reload
          socket = push_event(socket, "tree-updated", %{action: "add", node_id: new_node.id})

          {:noreply,
           socket
           |> assign(:tree, tree)
           |> assign(:dropdown_options, dropdown_options)
           |> assign(:tree_version, new_tree_version)
           |> put_flash(:info, "User added successfully!")
           |> assign(:show_form, false)
           |> assign(:show_add_person_modal, false)
           |> assign(:form_data, %{"name" => "", "role" => "", "reports_to" => ""})}
        {:error, changeset} ->
          Logger.error("[LiveView] Failed to add node: #{inspect(changeset.errors)}")
          {:noreply, put_flash(socket, :error, "Failed to add user. Errors: #{inspect(changeset.errors)}")}
      end
    end
  end

  def handle_event("edit_node", %{"node_id" => node_id}, socket) do
    Logger.info("[LiveView] Edit node event triggered for node_id: #{node_id}")
    Logger.info("[LiveView] Current socket assigns: #{inspect(socket.assigns, pretty: true)}")

    # Force refresh from database before getting node (silent to avoid recursion)
    TreeStorage.refresh_from_database_silent()

    # Get node from database
    node = TreeStorage.get_node(node_id)
    Logger.info("[LiveView] Retrieved node: #{inspect(TreeNode.safe_inspect(node))}")

    if node do
      parts = String.split(node.name, " - ", parts: 2)
      {role, name} = case parts do
        [role, name] -> {role, name}
        [single_name] -> {"", single_name}
      end

      edit_form_data = %{"name" => name, "role" => role, "node_id" => node_id}
      Logger.info("[LiveView] Edit form data prepared: #{inspect(edit_form_data)}")

      socket =
        socket
        |> assign(:editing_node, node)
        |> assign(:edit_form_data, edit_form_data)
        |> assign(:show_edit_person_modal, true)
        |> assign(:show_group_modal, false)  # Close group modal when editing
        |> assign(:form_error, nil)
        |> assign(:show_form, false)
        |> assign(:group_members, [])  # Clear group members
        |> assign(:group_title, "")   # Clear group title

      Logger.info("[LiveView] Edit form state updated successfully")
      {:noreply, socket}
    else
      Logger.error("[LiveView] Node not found for id: #{node_id}")

      # Get available node IDs for debugging
      all_entries = :ets.tab2list(:org_tree_storage)
      available_ids = Enum.map(all_entries, fn {k, _} -> k end)
      Logger.error("[LiveView] Available node IDs in ETS: #{inspect(available_ids)}")

      # Try to refresh from database and get the node again
      TreeStorage.refresh_from_database_silent()
      refreshed_node = TreeStorage.get_node(node_id)

      if refreshed_node do
        Logger.info("[LiveView] Node found after refresh, proceeding with edit")
        # Recursively call handle_event to avoid code duplication
        handle_event("edit_node", %{"node_id" => node_id}, socket)
      else
        Logger.error("[LiveView] Node still not found after refresh")
        {:noreply, put_flash(socket, :error, "Node #{node_id} not found. The node may have been deleted or the page needs to be refreshed.")}
      end
    end
  end

  def handle_event("update_node", _params, socket) do
    Logger.info("[LiveView] Update node event triggered")
    Logger.info("[LiveView] Socket assigns: #{inspect(socket.assigns, pretty: true)}")

    %{:edit_form_data => %{"name" => name, "role" => role, "node_id" => node_id}} = socket.assigns

    Logger.info("[LiveView] Updating node: id=#{node_id}, name=#{name}, role=#{role}")

    if String.trim(name) == "" or String.trim(role) == "" do
      socket = assign(socket, :form_error, "Please fill in all fields.")
      {:noreply, socket}
    else
      new_name = "#{role} - #{name}"
      Logger.info("[LiveView] New node name: #{new_name}")

      case TreeStorage.update_node(node_id, %{name: new_name}) do
        {:ok, updated_node} ->
          Logger.info("[LiveView] Node updated successfully: #{inspect(TreeNode.safe_inspect(updated_node))}")

          # Force a complete refresh of the tree data using the new function
          TreeStorage.force_refresh_tree()
          tree = TreeStorage.get_root_node()
          dropdown_options = extract_paths(tree)

          # Increment tree version to force complete re-render
          new_tree_version = socket.assigns.tree_version + 1

          # If group modal is open, refresh it based on current group id
          socket = if socket.assigns.show_group_modal && socket.assigns.current_group_id do
            send(self(), {:refresh_group_modal, %{"group_id" => socket.assigns.current_group_id}})
            socket
          else
            socket
          end

          # Push event to trigger page reload
          socket = push_event(socket, "tree-updated", %{action: "edit", node_id: node_id})

          {:noreply,
           socket
           |> assign(:tree, tree)
           |> assign(:dropdown_options, dropdown_options)
           |> assign(:tree_version, new_tree_version)
           |> put_flash(:info, "Node updated successfully!")
           |> assign(:show_edit_form, false)
           |> assign(:show_edit_person_modal, false)
           |> assign(:editing_node, nil)
           |> assign(:form_error, nil)
           |> assign(:edit_form_data, %{"name" => "", "role" => "", "node_id" => ""})
           }
        {:error, error} ->
          Logger.error("[LiveView] Failed to update node: #{inspect(error)}")
          {:noreply, put_flash(socket, :error, "Failed to update node: #{inspect(error)}")}
      end
    end
  end

  def handle_event("update_edit_form", %{"edit_user" => form_data}, socket) do
    Logger.info("[LiveView] Update edit form: #{inspect(form_data)}")
    {:noreply, assign(socket, :edit_form_data, form_data)}
  end

  def handle_event("cancel_edit", _params, socket) do
    Logger.info("[LiveView] Cancel edit event")
    socket =
      socket
      |> assign(:show_edit_form, false)
      |> assign(:show_edit_person_modal, false)
      |> assign(:editing_node, nil)
      |> assign(:form_error, nil)

    {:noreply, socket}
  end

  def handle_event("confirm_delete_node", %{"node_id" => node_id}, socket) do
    {:noreply, assign(socket, :node_to_delete, node_id)}
  end

  def handle_event("cancel_delete_node", _params, socket) do
    {:noreply, assign(socket, :node_to_delete, nil)}
  end

  def handle_event("delete_node", %{"node_id" => node_id}, socket) do
    Logger.info("[LiveView] Delete node event triggered for node_id: #{node_id}")
    Logger.info("[LiveView] Current socket assigns: #{inspect(socket.assigns, pretty: true)}")

    # Force refresh from database before deletion (silent to avoid recursion)
    TreeStorage.refresh_from_database_silent()

    Logger.info("[LiveView] Attempting to delete node (and subtree) with id: #{node_id}")

      case TreeStorage.delete_node_and_refresh(node_id) do
        :ok ->
          Logger.info("[LiveView] Node deleted successfully")

          # Force a complete refresh of the tree data using the new function
          TreeStorage.force_refresh_tree()
          tree = TreeStorage.get_root_node()
          dropdown_options = extract_paths(tree)

          # Increment tree version to force complete re-render
          new_tree_version = socket.assigns.tree_version + 1

          # Push event to trigger page reload
          socket = push_event(socket, "tree-updated", %{action: "delete", node_id: node_id})

          # If group modal is open, refresh it based on current group id
          socket = if socket.assigns.show_group_modal && socket.assigns.current_group_id do
            send(self(), {:refresh_group_modal, %{"group_id" => socket.assigns.current_group_id}})
            socket
          else
            socket
          end

          {:noreply,
           socket
           |> assign(:tree, tree)
           |> assign(:dropdown_options, dropdown_options)
           |> assign(:tree_version, new_tree_version)
         |> put_flash(:info, "Group deleted successfully!")
           |> assign(:show_edit_form, false)
           |> assign(:editing_node, nil)
           |> assign(:form_error, nil)
           |> assign(:node_to_delete, nil)
           }
        {:error, error} ->
          Logger.error("[LiveView] Failed to delete node: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to delete group: #{inspect(error)}")}
    end
  end

  # Open the Add Person modal with the selected group pre-filled as "Reports To"
  def handle_event("open_add_person", %{"group_id" => group_id}, socket) do
    Logger.info("[LiveView] Opening Add Person form for group_id=#{group_id}")

    group_id_int =
      cond do
        is_integer(group_id) -> group_id
        is_binary(group_id) -> String.to_integer(group_id)
        true -> nil
      end

    {:noreply,
     socket
     |> assign(:show_add_person_modal, true)
     |> assign(:form_error, nil)
     |> assign(:form_data, %{"name" => "", "role" => "", "reports_to" => group_id_int})
     |> assign(:show_group_modal, false)}
  end

  def handle_event("open_add_person", _params, socket) do
    Logger.info("[LiveView] Opening Add Person form (no group specified)")
    {:noreply,
     socket
     |> assign(:show_add_person_modal, true)
     |> assign(:form_error, nil)
     |> assign(:form_data, %{"name" => "", "role" => "", "reports_to" => ""})
     |> assign(:show_group_modal, false)}
  end

  def handle_event("close_add_person_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_person_modal, false)
     |> assign(:form_error, nil)}
  end

  def handle_event("show_group_members", %{"group_id" => group_id}, socket) do
    Logger.info("[LiveView] show_group_members event triggered with group_id: #{group_id}")

    # Refresh silently then fetch children
    TreeStorage.refresh_from_database_silent()

    node = TreeStorage.get_node(group_id)
    if node do
      children = TreeStorage.get_children(node.id)
      {members, _subgroups} = split_members_and_subgroups(children)

      group_title = (node.name || "Team") <> " (" <> Integer.to_string(length(members)) <> ")"

      {:noreply,
       socket
       |> assign(:show_group_modal, true)
       |> assign(:group_members, members)
       |> assign(:group_title, group_title)
       |> assign(:current_group_id, node.id)
       |> assign(:show_edit_form, false)}
    else
      {:noreply, put_flash(socket, :error, "Group not found.")}
    end
  end

  # Edit Group name modal events
  def handle_event("open_edit_group", %{"group_id" => group_id}, socket) do
    Logger.info("[LiveView] Open edit group modal for group_id=#{group_id}")
    TreeStorage.refresh_from_database_silent()
    case TreeStorage.get_node(group_id) do
      nil -> {:noreply, put_flash(socket, :error, "Group not found")}
      node ->
        {:noreply,
         socket
         |> assign(:show_edit_group_modal, true)
         |> assign(:edit_group_data, %{"name" => node.name, "node_id" => group_id})
         |> assign(:show_group_modal, false)
         |> assign(:form_error, nil)}
    end
  end

  def handle_event("update_edit_group_form", %{"group" => %{"name" => name}}, socket) do
    {:noreply, update(socket, :edit_group_data, &Map.put(&1, "name", name))}
  end

  def handle_event("save_edit_group", _params, socket) do
    %{"name" => name, "node_id" => node_id} = socket.assigns.edit_group_data
    Logger.info("[LiveView] Save edit group id=#{node_id} name=#{name}")

    case TreeStorage.update_node(node_id, %{name: name}) do
      {:ok, _updated} ->
        TreeStorage.force_refresh_tree()
        tree = TreeStorage.get_root_node()
        dropdown_options = extract_paths(tree)
        new_tree_version = socket.assigns.tree_version + 1

        # If the group modal is currently showing this group, refresh it
        socket = if socket.assigns.current_group_id == node_id do
          send(self(), {:refresh_group_modal, %{"group_id" => node_id}})
          socket
        else
          socket
        end

        # Push event to trigger client refresh
        socket = push_event(socket, "tree-updated", %{action: "edit_group", node_id: node_id})

        {:noreply,
         socket
         |> assign(:tree, tree)
         |> assign(:dropdown_options, dropdown_options)
         |> assign(:tree_version, new_tree_version)
         |> assign(:show_edit_group_modal, false)
         |> assign(:edit_group_data, %{"name" => "", "node_id" => ""})
         |> put_flash(:info, "Group updated successfully")}
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to update group: #{inspect(error)}")}
    end
  end

  def handle_event("cancel_edit_group", _params, socket) do
    {:noreply, socket |> assign(:show_edit_group_modal, false) |> assign(:edit_group_data, %{"name" => "", "node_id" => ""})}
  end

  # Inline Add Group form events
  def handle_event("open_add_group", %{"parent_id" => parent_id}, socket) do
    Logger.info("[LiveView] Opening Add Group form for parent_id=#{parent_id}")
    parent_id_int =
      cond do
        is_integer(parent_id) -> parent_id
        is_binary(parent_id) -> String.to_integer(parent_id)
        true -> nil
      end

    {:noreply,
     socket
     |> assign(:add_group_parent_id, parent_id_int)
     |> assign(:add_group_name, "")
     |> assign(:show_edit_form, false)
     |> assign(:show_group_modal, false)
     |> assign(:show_add_group_modal, true)}
  end

  def handle_event("cancel_add_group", _params, socket) do
    Logger.info("[LiveView] Cancel Add Group form")
    {:noreply,
     socket
     |> assign(:add_group_parent_id, nil)
     |> assign(:add_group_name, "")
     |> assign(:show_add_group_modal, false)}
  end

  def handle_event("update_add_group_form", %{"group" => %{"name" => name}}, socket) do
    {:noreply, assign(socket, :add_group_name, name)}
  end

  def handle_event("add_group", _params, socket) do
    Logger.info("[LiveView] Add group event triggered")
    name = String.trim(socket.assigns.add_group_name || "")
    parent_id = socket.assigns.add_group_parent_id

    if name == "" do
      {:noreply, put_flash(socket, :error, "Please provide a group name.")}
    else
      case TreeStorage.add_node(name, parent_id, true) do
        {:ok, new_node} ->
          Logger.info("[LiveView] Group added successfully: #{inspect(TreeNode.safe_inspect(new_node))}")

          # Refresh tree and dropdowns
          TreeStorage.force_refresh_tree()
          tree = TreeStorage.get_root_node()
          dropdown_options = extract_paths(tree)

          new_tree_version = socket.assigns.tree_version + 1

          socket = push_event(socket, "tree-updated", %{action: "add_group", node_id: new_node.id})

          {:noreply,
           socket
           |> assign(:tree, tree)
           |> assign(:dropdown_options, dropdown_options)
           |> assign(:tree_version, new_tree_version)
           |> put_flash(:info, "Group added successfully!")
           |> assign(:add_group_parent_id, nil)
           |> assign(:add_group_name, "")
           |> assign(:show_add_group_modal, false)}
        {:error, changeset} ->
          Logger.error("[LiveView] Failed to add group: #{inspect(changeset.errors)}")
          {:noreply, put_flash(socket, :error, "Failed to add group. Errors: #{inspect(changeset.errors)}")}
      end
    end
  end

  def handle_event("close_group_modal", _params, socket) do
    Logger.info("[LiveView] Closing group modal")
    socket =
      socket
      |> assign(:show_group_modal, false)
      |> assign(:group_members, [])
      |> assign(:group_title, "")
    {:noreply, socket}
  end

  def handle_event("refresh_group_modal", %{"group_id" => group_id}, socket) do
    Logger.info("[LiveView] Refreshing group modal for group_id: #{group_id}")

    TreeStorage.refresh_from_database_silent()
    node = TreeStorage.get_node(group_id)
    if node do
      children = TreeStorage.get_children(node.id)
      {members, _subgroups} = split_members_and_subgroups(children)
      group_title = (node.name || "Team") <> " (" <> Integer.to_string(length(members)) <> ")"

        {:noreply,
         socket
       |> assign(:group_members, members)
       |> assign(:group_title, group_title)
       |> assign(:current_group_id, node.id)}
    else
      {:noreply,
       socket
       |> assign(:show_group_modal, false)
       |> assign(:group_members, [])
       |> assign(:group_title, "")
       |> put_flash(:info, "Group has been removed or modified.")}
    end
  end

  # Search: update query and results
  def handle_event("update_search", %{"q" => query}, socket) do
    q = String.trim(query || "")
    {results, show} = if q == "" do
      {[], false}
    else
      {search_people(q), true}
    end
    {:noreply, socket |> assign(:search_query, q) |> assign(:search_results, results) |> assign(:show_search_results, show)}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, assign(socket, :search_query, "") |> assign(:search_results, []) |> assign(:show_search_results, false)}
  end

  def handle_event("goto_person", %{"person_id" => person_id}, socket) do
    Logger.info("[LiveView] goto_person id=#{person_id}")
    TreeStorage.refresh_from_database_silent()
    person = TreeStorage.get_node(person_id)
    group_id = if person, do: person.parent_id, else: nil

    socket = if group_id do
      # Open/refresh group modal
      node = TreeStorage.get_node(group_id)
      children = TreeStorage.get_children(group_id)
      {members, _subgroups} = split_members_and_subgroups(children)
      group_title = (node.name || "Team") <> " (" <> Integer.to_string(length(members)) <> ")"

      socket
      |> assign(:show_group_modal, true)
      |> assign(:group_members, members)
      |> assign(:group_title, group_title)
      |> assign(:current_group_id, group_id)
      |> assign(:highlight_person_id, person_id)
      |> push_event("scroll-to-group", %{group_id: group_id})
      |> push_event("highlight-person", %{person_id: person_id})
    else
      socket
    end

    {:noreply, socket}
  end

  def handle_event("debug_state", _params, socket) do
    Logger.info("[LiveView] Debug state event triggered")

    # Force refresh from database (silent to avoid recursion)
    TreeStorage.refresh_from_database_silent()

    # Get current tree state
    tree = TreeStorage.get_root_node()
    all_nodes = :ets.tab2list(:org_tree_storage)

    # Create a summary of ETS entries to avoid massive output
    ets_summary = Enum.map(all_nodes, fn {key, value} ->
      case value do
        %{id: id, name: name, parent_id: parent_id} -> {key, %{id: id, name: name, parent_id: parent_id}}
        _ -> {key, "other"}
      end
    end)

    debug_info = %{
      tree_present: tree != nil,
      tree_summary: if(tree, do: %{id: tree.id, name: tree.name, parent_id: tree.parent_id}, else: "nil"),
      ets_entry_count: length(all_nodes),
      ets_summary: ets_summary,
      socket_assigns_keys: Map.keys(socket.assigns)
    }

    Logger.info("[LiveView] Debug info: #{inspect(debug_info, pretty: true)}")

    {:noreply, put_flash(socket, :info, "Debug info logged. Check console for details.")}
  end

  def handle_info(:tree_updated, socket) do
    Logger.info("[LiveView] Received :tree_updated in handle_info")
    Logger.info("[LiveView] Current socket assigns before update: #{inspect(socket.assigns, pretty: true)}")

    # Add a small delay to ensure database consistency
    Process.sleep(10)

    # Force refresh from database (silent to avoid recursion)
    TreeStorage.refresh_from_database_silent()

    tree = TreeStorage.get_root_node()
    Logger.info("[LiveView] Loaded tree after update: #{if tree, do: "present", else: "nil"}")
    Logger.info("[LiveView] Tree details: #{inspect(tree, pretty: true)}")

    # Update dropdown options
    dropdown_options = extract_paths(tree)
    Logger.info("[LiveView] Updated dropdown options: #{inspect(dropdown_options)}")

    {:noreply,
     socket
     |> assign(:tree, tree)
     |> assign(:dropdown_options, dropdown_options)
     |> update(:tree_version, &(&1 + 1))
     |> clear_flash()}  # Clear any existing flash messages
  end

  def handle_info({:refresh_group_modal, %{"group_id" => group_id}}, socket) do
    Logger.info("[LiveView] Received refresh_group_modal message for group_id: #{group_id}")

    # Force refresh from database
    TreeStorage.refresh_from_database_silent()

    # Re-fetch the group data directly
    node = TreeStorage.get_node(group_id)
    if node do
      children = TreeStorage.get_children(node.id)
      {members, _subgroups} = split_members_and_subgroups(children)
      group_title = (node.name || "Team") <> " (" <> Integer.to_string(length(members)) <> ")"

      # Increment tree version to force complete re-render
      new_tree_version = socket.assigns.tree_version + 1

      {:noreply,
       socket
       |> assign(:tree, TreeStorage.get_root_node())
       |> assign(:tree_version, new_tree_version)
       |> assign(:group_members, members)
       |> assign(:group_title, group_title)
       |> assign(:current_group_id, node.id)}
    else
      # Group no longer exists, close the modal
      {:noreply,
       socket
       |> assign(:show_group_modal, false)
       |> assign(:group_members, [])
       |> assign(:group_title, "")
       |> put_flash(:info, "Group has been removed or modified.")}
    end
  end

  defp extract_paths(nil), do: []
  defp extract_paths(node) do
    do_extract_paths(node, [], [])
  end

  defp is_group_node?(nil), do: false
  defp is_group_node?(node) do
    case Map.fetch(node, :is_group) do
      {:ok, true} -> true
      {:ok, false} -> false
      :error ->
        not Enum.empty?(TreeStorage.get_children(node.id))
    end
  end

  defp do_extract_paths(nil, _, _), do: []
  defp do_extract_paths(node, id_path, name_path) do
    if is_group_node?(node) do
      current_id_path = id_path ++ [node.id]
      current_name_path = name_path ++ [node.name]
      display_path = Enum.join(current_name_path, " > ")
      value_path = node.id
      paths = [%{display: display_path, value: value_path}]

      children = TreeStorage.get_children(node.id)
      {_members, sub_groups} = split_members_and_subgroups(children)
      child_paths = Enum.flat_map(sub_groups, &do_extract_paths(&1, current_id_path, current_name_path))
      paths ++ child_paths
    else
      []
    end
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
    # If is_group flag present, use it; otherwise fallback to leaf-ness
    case Map.fetch(node, :is_group) do
      {:ok, true} -> false
      {:ok, false} -> true
      :error -> Enum.empty?(TreeStorage.get_children(node.id))
    end
  end

  # Identify leaves (members) and non-leaves (sub-groups)
  defp split_members_and_subgroups(children) do
    Enum.split_with(children, &is_leaf?/1)
  end

  # Calculate bottom-up positioning for the entire tree
  defp calculate_tree_positions(node, level \\ 0)
  defp calculate_tree_positions(nil, _level), do: nil
  defp calculate_tree_positions(node, level) do
    children = TreeStorage.get_children(node.id)
    {_members, sub_groups} = split_members_and_subgroups(children)
    all_children = sub_groups

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

  # Search helpers
  defp flatten_people(nil), do: []
  defp flatten_people(node) do
    children = TreeStorage.get_children(node.id)
    {members, sub_groups} = split_members_and_subgroups(children)
    Enum.concat([
      members,
      Enum.flat_map(sub_groups, &flatten_people/1)
    ])
  end

  defp search_people(term) do
    root = TreeStorage.get_root_node()
    people = case root do
      nil -> []
      node -> flatten_people(node)
    end

    downcased = String.downcase(term)
    Enum.filter(people, fn p -> String.contains?(String.downcase(p.name || ""), downcased) end)
  end

  # Function component attributes
  attr :node, :any, required: true
  attr :add_group_parent_id, :any, default: nil
  attr :add_group_name, :string, default: ""

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

    # Pre-calculate members and subgroups for each node to avoid tuple rendering issues
    nodes_with_children = Enum.map(positioned_nodes, fn positioned_node ->
      children = TreeOrg.TreeStorage.get_children(positioned_node.node.id)
      {members, sub_groups} = split_members_and_subgroups(children || [])
      # Add the new keys to the existing map
      Map.merge(positioned_node, %{
        members: members || [],
        sub_groups: sub_groups || []
      })
    end)

    # Group nodes by level for easier rendering (use nodes_with_children to include members)
    nodes_by_level = Enum.group_by(nodes_with_children, & &1.level)

    assigns = assigns
    |> Map.put(:positioned_nodes, nodes_with_children)
    |> Map.put(:connection_lines, connection_lines)
    |> Map.put(:container_width, container_width)
    |> Map.put(:container_height, container_height)
    |> Map.put(:min_x, min_x)
    |> Map.put(:nodes_by_level, nodes_by_level)
    |> Map.put(:max_level, max_level)

    ~H"""
    <div class="flex flex-col items-center relative w-full overflow-x-auto">
      <!--  chart container the @is the calculated container width and height to define space needed for svg & nodes-->
      <div class="relative" style={"width: #{@container_width}px; height: #{@container_height}px;"}>

        <!-- SVG for connection lines z-10 to ensure it sits behind other elements & pointer... allows click to pass through it so btns arent blocked -->
        <svg
          class="absolute top-0 left-0 pointer-events-none z-10"
          width={@container_width}
          height={@container_height}
        >
          <%= for {x1, y1, x2, y2} <- @connection_lines do %>
            <%=
              mid_y = trunc((y1 + y2) / 2)
              adj_x1 = x1 - @min_x + 150
              adj_x2 = x2 - @min_x + 150
            %>

            <!-- Vertical line from y1 to mid_y -->
            <line
              x1={adj_x1}
              y1={y1}
              x2={adj_x1}
              y2={mid_y}
              stroke="#6366f1"
              stroke-width="2"
              opacity="0.7"
            />

            <!-- Horizontal line from x1 to x2 at mid_y -->
            <line
              x1={adj_x1}
              y1={mid_y}
              x2={adj_x2}
              y2={mid_y}
              stroke="#6366f1"
              stroke-width="2"
              opacity="0.7"
            />

            <!-- Vertical line from mid_y to y2 -->
            <line
              x1={adj_x2}
              y1={mid_y}
              x2={adj_x2}
              y2={y2}
              stroke="#6366f1"
              stroke-width="2"
              opacity="0.7"
            />
          <% end %>
        </svg>

        <!-- Render group nodes at their calculated positions using nested loop by levels -->
        <%= for {level, nodes} <- @nodes_by_level do %>
          <%= for positioned_node <- nodes do %>
            <div
              class="absolute z-20"
              id={"group-#{positioned_node.node.id}"}
              style={"left: #{positioned_node.x - @min_x + 150}px; top: #{level * 150}px; transform: translateX(-50%);"}
            >
              <div class="relative group flex flex-col items-center">
                <div
                  phx-click="show_group_members"
                  phx-value-group_id={positioned_node.node.id}
                  class="tree-node cursor-pointer mt-4 px-12 py-3 border-2 border-green-200 bg-gradient-to-br from-green-50 to-green-100 hover:from-green-100 hover:to-green-150 rounded-xl shadow-lg hover:shadow-xl transition-all duration-300 inline-block min-w-[280px] max-w-[320px]"
                >
                  <!--pple icon -->
                  <div class="flex items-start space-x-4">
                    <div class="w-8 h-8 rounded-full flex items-center justify-center text-white font-bold text-lg bg-green-500 shadow-md">👥</div>
                    <div class="flex-1 min-w-0">
                      <div class="font-semibold text-gray-800 text-lg truncate"><%= positioned_node.node.name %></div>
                      <div class="text-sm text-gray-600"><%= length(positioned_node.members || []) %> members</div>
                      <div class="mt-2 flex items-center -space-x-2">
                        <%= for {member, _idx} <- Enum.with_index(Enum.take(positioned_node.members || [], 6)) do %>
                          <div class={"w-7 h-7 rounded-full ring-2 ring-white flex items-center justify-center text-white text-[10px] font-bold shadow #{get_avatar_color(member.id)}"} title={member.name}>
                            <%= (member.name |> String.split(" ") |> Enum.map(&String.first/1) |> Enum.join("")) %>
                      </div>
                        <% end %>
                        <%= if length(positioned_node.members || []) > 6 do %>
                          <div class="w-7 h-7 rounded-full ring-2 ring-white bg-gray-300 text-gray-700 text-[10px] font-semibold flex items-center justify-center shadow">+<%= length(positioned_node.members || []) - 6 %></div>
                        <% end %>
                      </div>
                    </div>
                  </div>

                  <!-- Hover Delete (top-right inside) -->
                  <div class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex space-x-2 mb-48">
                    <button
                      phx-click="open_edit_group"
                      phx-value-group_id={positioned_node.node.id}
                      class="bg-amber-500 hover:bg-amber-600 text-white text-xs px-2 py-1 rounded shadow-md transition-colors duration-200"
                      title="Edit Group"
                      type="button"
                    >✏️</button>
                    <button
                      phx-click="open_add_person"
                      phx-value-group_id={positioned_node.node.id}
                      class="bg-emerald-500 hover:bg-emerald-600 text-white text-xs px-2 py-1 rounded shadow-md transition-colors duration-200"
                      title="Add Person to this Group"
                      type="button"
                    >➕</button>
                    <%= if positioned_node.node.parent_id do %>
                      <button
                        phx-click="confirm_delete_node"
                        phx-value-node_id={positioned_node.node.id}
                        class="bg-red-500 hover:bg-red-600 text-white text-xs px-2 py-1 rounded shadow-md transition-colors duration-200"
                        title="Delete Group"
                        type="button"
                      >🗑️</button>
                    <% end %>
                  </div>
                </div>

                <!-- Add Sub-Group below node -->
                <div class="relative flex flex-col items-center mt-2">
                  <div class="w-[2px] h-3 bg-green-300 opacity-0 group-hover:opacity-100 transition-opacity duration-200"></div>
                  <button
                    phx-click="open_add_group"
                    phx-value-parent_id={positioned_node.node.id}
                    class="opacity-0 group-hover:opacity-100 transition-opacity duration-200 bg-green-500 hover:bg-green-600 text-white rounded-full w-8 h-8 flex items-center justify-center shadow"
                    title="Add Sub-Group"
                    type="button"
                  >
                    ⬇️
                  </button>
                </div>

                <!-- Inline Add Group form -->
                <%= if @add_group_parent_id == positioned_node.node.id do %>
                  <div class="hidden">
                    <h4 class="text-sm font-semibold text-gray-800 mb-2">Add Group under "<%= positioned_node.node.name %>"</h4>
                    <.form for={%{}} phx-submit="add_group" phx-change="update_add_group_form">
                      <div class="space-y-3">
                        <div>
                          <label class="block text-xs font-medium text-gray-700 mb-1">Group Name</label>
                          <input type="text" name="group[name]" value={@add_group_name} class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent transition-all duration-200" placeholder="e.g. Engineering" />
                        </div>
                        <div class="flex items-center justify-end space-x-2 pt-1">
                          <button type="button" phx-click="cancel_add_group" class="px-3 py-2 text-xs bg-gray-200 hover:bg-gray-300 text-gray-800 rounded">Cancel</button>
                          <button type="submit" class="px-3 py-2 text-xs bg-green-600 hover:bg-green-700 text-white rounded">Add Group</button>
                        </div>
                      </div>
                    </.form>
                </div>
              <% end %>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
