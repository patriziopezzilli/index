import SwiftUI

struct QueryResultView: View {
    let result: QueryResult

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = result.error {
                ErrorResultView(error: error)
            } else if let rowsAffected = result.rowsAffected {
                AffectedRowsView(rowsAffected: rowsAffected, executionTime: result.executionTime)
            } else if !result.columns.isEmpty {
                TableResultView(columns: result.columns, rows: result.rows, executionTime: result.executionTime)
            } else {
                SuccessResultView(executionTime: result.executionTime)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorResultView: View {
    let error: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)

                    Text("Query Failed")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding()

                Text(error)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.red.opacity(0.8))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding(.horizontal)
            }
        }
    }
}

struct AffectedRowsView: View {
    let rowsAffected: Int
    let executionTime: TimeInterval

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Query Executed Successfully")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                VStack(spacing: 8) {
                    Text("\(rowsAffected) row\(rowsAffected == 1 ? "" : "s") affected")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))

                    Text("Execution time: \(String(format: "%.2f", executionTime))s")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct SuccessResultView: View {
    let executionTime: TimeInterval

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Query Executed Successfully")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Execution time: \(String(format: "%.2f", executionTime))s")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct TableResultView: View {
    let columns: [String]
    let rows: [[String]]
    let executionTime: TimeInterval

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(rows.count) row\(rows.count == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Text("Execution time: \(String(format: "%.2f", executionTime))s")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(Color.white.opacity(0.05))

            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(columns, id: \.self) { column in
                            Text(column)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(minWidth: 150, alignment: .leading)
                                .padding()
                                .background(Color.blue.opacity(0.2))
                        }
                    }

                    ForEach(rows.indices, id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            ForEach(rows[rowIndex].indices, id: \.self) { colIndex in
                                Text(rows[rowIndex][colIndex])
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(minWidth: 150, alignment: .leading)
                                    .padding()
                                    .background(rowIndex.isMultiple(of: 2) ? Color.white.opacity(0.03) : Color.clear)
                            }
                        }
                    }
                }
            }
        }
    }
}
