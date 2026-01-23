import SwiftUI

struct QueryTemplatesView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @State private var selectedCategory = "CRUD"

    let categories = ["CRUD", "Analytics", "Admin", "Schema"]

    let templates: [String: [QueryTemplate]] = [
        "CRUD": [
            QueryTemplate(name: "SELECT All", query: "SELECT * FROM table_name;", description: "Select all records from a table"),
            QueryTemplate(name: "SELECT with WHERE", query: "SELECT * FROM table_name WHERE column_name = 'value';", description: "Select records with condition"),
            QueryTemplate(name: "INSERT", query: "INSERT INTO table_name (column1, column2) VALUES ('value1', 'value2');", description: "Insert new record"),
            QueryTemplate(name: "UPDATE", query: "UPDATE table_name SET column_name = 'new_value' WHERE id = 1;", description: "Update existing record"),
            QueryTemplate(name: "DELETE", query: "DELETE FROM table_name WHERE id = 1;", description: "Delete record")
        ],
        "Analytics": [
            QueryTemplate(name: "COUNT Records", query: "SELECT COUNT(*) FROM table_name;", description: "Count total records"),
            QueryTemplate(name: "GROUP BY", query: "SELECT column_name, COUNT(*) FROM table_name GROUP BY column_name;", description: "Group and count records"),
            QueryTemplate(name: "AVG Value", query: "SELECT AVG(column_name) FROM table_name;", description: "Calculate average value"),
            QueryTemplate(name: "MAX Value", query: "SELECT MAX(column_name) FROM table_name;", description: "Find maximum value"),
            QueryTemplate(name: "MIN Value", query: "SELECT MIN(column_name) FROM table_name;", description: "Find minimum value")
        ],
        "Admin": [
            QueryTemplate(name: "Show Tables", query: "SHOW TABLES;", description: "List all tables"),
            QueryTemplate(name: "Table Structure", query: "DESCRIBE table_name;", description: "Show table structure"),
            QueryTemplate(name: "Create Index", query: "CREATE INDEX idx_name ON table_name (column_name);", description: "Create database index"),
            QueryTemplate(name: "Show Indexes", query: "SHOW INDEX FROM table_name;", description: "List table indexes"),
            QueryTemplate(name: "Kill Process", query: "KILL process_id;", description: "Terminate database process")
        ],
        "Schema": [
            QueryTemplate(name: "Create Table", query: """
CREATE TABLE table_name (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
""", description: "Create new table"),
            QueryTemplate(name: "Add Column", query: "ALTER TABLE table_name ADD COLUMN column_name VARCHAR(255);", description: "Add column to table"),
            QueryTemplate(name: "Drop Column", query: "ALTER TABLE table_name DROP COLUMN column_name;", description: "Remove column from table"),
            QueryTemplate(name: "Create View", query: "CREATE VIEW view_name AS SELECT * FROM table_name WHERE condition;", description: "Create database view")
        ]
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryButton(
                                title: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.secondarySystemBackground))

                // Templates List
                ScrollView {
                    VStack(spacing: 16) {
                        if let categoryTemplates = templates[selectedCategory] {
                            ForEach(categoryTemplates) { template in
                                TemplateCard(template: template) {
                                    // Copy to clipboard
                                    UIPasteboard.general.string = template.query
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Query Templates")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct QueryTemplate: Identifiable {
    let id = UUID()
    let name: String
    let query: String
    let description: String
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

struct TemplateCard: View {
    let template: QueryTemplate
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    Text(template.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                        )
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(template.query.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .textSelection(.enabled)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}