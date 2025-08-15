defmodule TreeOrg.Repo.Migrations.AddRootGroupAndConstraint do
  use Ecto.Migration

  def up do
    # Ensure only a single root node (parent_id IS NULL) can exist
    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS only_one_root_node
    ON tree_nodes ((1))
    WHERE parent_id IS NULL;
    """)

    # Seed a default root group if none exists yet
    execute("""
    INSERT INTO tree_nodes (name, parent_id, inserted_at, updated_at)
    SELECT 'Root', NULL, NOW(), NOW()
    WHERE NOT EXISTS (
      SELECT 1 FROM tree_nodes WHERE parent_id IS NULL
    );
    """)
  end

  def down do
    # Remove the seeded root group only if it matches the default name we created
    execute("""
    DELETE FROM tree_nodes
    WHERE parent_id IS NULL AND name = 'Root';
    """)

    execute("""
    DROP INDEX IF EXISTS only_one_root_node;
    """)
  end
end
