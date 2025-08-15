defmodule TreeOrg.Repo.Migrations.AddRootGroupAndConstraint do
  use Ecto.Migration

  def up do
    # Ensure only a single root node (parent_id IS NULL) can exist
    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS only_one_root_node
    ON tree_nodes ((1))
    WHERE parent_id IS NULL;
    """)
  end

  def down do
    execute("""
    DROP INDEX IF EXISTS only_one_root_node;
    """)
  end
end
