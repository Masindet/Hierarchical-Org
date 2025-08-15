alias TreeOrg.Repo
alias TreeOrg.TreeNode

Repo.delete_all(TreeNode)

# === Helpers ===
defmodule Seeder do
  def create_group(name, parent_id \\ nil) do
    TreeOrg.Repo.insert!(%TreeOrg.TreeNode{
      name: name,
      parent_id: parent_id,
      is_group: true
    })
  end

  def create_team(parent, base_name, count) do
    for i <- 1..count do
      TreeOrg.Repo.insert!(%TreeOrg.TreeNode{
        name: "#{base_name} #{i}",
        parent_id: parent.id,
        is_group: false
      })
    end
    count
  end
end

total = 0

# === EXECUTIVE LEVEL ===
ceo = Seeder.create_group("CEO")

cto = Seeder.create_group("CTO", ceo.id)
cfo = Seeder.create_group("CFO", ceo.id)
coo = Seeder.create_group("COO", ceo.id)
cmo = Seeder.create_group("CMO", ceo.id)
cro = Seeder.create_group("CRO", ceo.id)
clo = Seeder.create_group("CLO", ceo.id)

# === ENGINEERING ===
vp_eng = Seeder.create_group("VP of Engineering", cto.id)

frontend_mgr = Seeder.create_group("Frontend Manager", vp_eng.id)
backend_mgr = Seeder.create_group("Backend Manager", vp_eng.id)
devops_mgr = Seeder.create_group("DevOps Manager", vp_eng.id)

total = total + Seeder.create_team(frontend_mgr, "Frontend Dev", 180)
total = total + Seeder.create_team(backend_mgr, "Backend Dev", 180)
total = total + Seeder.create_team(devops_mgr, "DevOps Engineer", 100)

# === QA ===
qa_mgr = Seeder.create_group("QA Manager", cto.id)
total = total + Seeder.create_team(qa_mgr, "QA Engineer", 80)

# === PRODUCT & DESIGN ===
vp_product = Seeder.create_group("VP of Product", cto.id)
pm_mgr = Seeder.create_group("Product Manager", vp_product.id)
ux_mgr = Seeder.create_group("UX Manager", vp_product.id)

total = total + Seeder.create_team(pm_mgr, "PM", 60)
total = total + Seeder.create_team(ux_mgr, "UX Designer", 60)

# === FINANCE & ACCOUNTING ===
finance_mgr = Seeder.create_group("Finance Manager", cfo.id)
accounting_mgr = Seeder.create_group("Accounting Manager", cfo.id)

total = total + Seeder.create_team(finance_mgr, "Financial Analyst", 60)
total = total + Seeder.create_team(accounting_mgr, "Accountant", 60)

# === HR ===
hr_mgr = Seeder.create_group("HR Manager", coo.id)
total = total + Seeder.create_team(hr_mgr, "HR Specialist", 50)

# === OPERATIONS ===
ops_mgr = Seeder.create_group("Operations Manager", coo.id)
total = total + Seeder.create_team(ops_mgr, "Ops Staff", 60)

# === SALES & MARKETING ===
sales_mgr = Seeder.create_group("Sales Manager", cro.id)
marketing_mgr = Seeder.create_group("Marketing Manager", cmo.id)

total = total + Seeder.create_team(sales_mgr, "Sales Rep", 90)
total = total + Seeder.create_team(marketing_mgr, "Marketing Executive", 90)

# === LEGAL ===
legal_mgr = Seeder.create_group("Legal Manager", clo.id)
total = total + Seeder.create_team(legal_mgr, "Legal Officer", 30)

# === SUPPORT ===
support_mgr = Seeder.create_group("Customer Support Manager", coo.id)
total = total + Seeder.create_team(support_mgr, "Support Agent", 70)

# === R&D ===
rnd_mgr = Seeder.create_group("R&D Manager", cto.id)
total = total + Seeder.create_team(rnd_mgr, "R&D Specialist", 60)

IO.puts("🎉 Seeded #{total} employees across all departments (plus groups)")
