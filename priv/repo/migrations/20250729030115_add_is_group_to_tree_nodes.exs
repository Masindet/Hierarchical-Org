defmodule TreeOrg.Repo.Migrations.AddIsGroupToTreeNodes do
  use Ecto.Migration

  def up do
    alter table(:tree_nodes) do
      add :is_group, :boolean, null: false, default: false
    end

    # Mark roots and any node that currently has children as groups
    execute "UPDATE tree_nodes SET is_group = true WHERE parent_id IS NULL"
    execute "UPDATE tree_nodes SET is_group = true WHERE id IN (SELECT DISTINCT parent_id FROM tree_nodes WHERE parent_id IS NOT NULL)"
  end

  def down do
    alter table(:tree_nodes) do
      remove :is_group
    end
  end
end
