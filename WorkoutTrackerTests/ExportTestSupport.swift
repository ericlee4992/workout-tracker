import Foundation

@testable import WorkoutTracker

/// A minimal RFC 4180 reader for the export tests, so they read the CSV the
/// way a spreadsheet would rather than by re-implementing the writer's
/// assumptions (a bug shared by writer and test is invisible).
enum TestCSV {

    /// Splits a rendered export into rows of fields. Handles quoted fields
    /// containing commas, doubled quotes, and embedded newlines.
    static func rows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var current = ""
        var quoted = false
        var characters = Array(text)
        var index = 0

        func endField() {
            fields.append(current)
            current = ""
        }
        func endRow() {
            endField()
            rows.append(fields)
            fields = []
        }

        while index < characters.count {
            let character = characters[index]
            if quoted {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        current.append("\"")
                        index += 1
                    } else {
                        quoted = false
                    }
                } else {
                    current.append(character)
                }
            } else {
                switch character {
                case "\"":
                    quoted = true
                case ",":
                    endField()
                // Swift reads CRLF as a *single* Character, so the pair has to
                // be matched as one — checking for "\r" alone silently never
                // fires and glues the whole file into one row.
                case "\r\n", "\r", "\n":
                    endRow()
                default:
                    current.append(character)
                }
            }
            index += 1
        }
        // A file ending in a terminator leaves nothing pending; anything else
        // is a final unterminated row.
        if !current.isEmpty || !fields.isEmpty {
            endRow()
        }
        return rows
    }

    enum ParseError: Error, Equatable {
        /// A quoted field never closed before end of file.
        case unclosedQuote
        /// Characters appeared after a closing quote, e.g. `"a"b`.
        case textAfterClosingQuote(row: Int)
        /// A record with the wrong number of fields for the export dialect.
        case wrongFieldCount(row: Int, count: Int)
        /// A record terminated by a bare CR or LF rather than CRLF.
        case badLineTerminator(row: Int)
    }

    /// Strict reader for the dialect the export actually claims (D32): CRLF
    /// terminators, quoted fields closed properly, and exactly
    /// `ExportCSV.header.count` fields per record.
    ///
    /// The permissive `rows` reader above is convenient for assertions, but it
    /// accepts malformed input — so on its own it could bless a writer bug as a
    /// round trip (codex-review, finding 11). This one refuses.
    static func strictRows(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var current = ""
        var quoted = false
        var justClosedQuote = false
        var fieldWasQuoted = false
        let scalars = Array(text.unicodeScalars)
        var index = 0

        while index < scalars.count {
            let scalar = scalars[index]
            if quoted {
                if scalar == "\"" {
                    if index + 1 < scalars.count, scalars[index + 1] == "\"" {
                        current.unicodeScalars.append("\"")
                        index += 1
                    } else {
                        quoted = false
                        justClosedQuote = true
                    }
                } else {
                    current.unicodeScalars.append(scalar)
                }
                index += 1
                continue
            }

            switch scalar {
            case "\"":
                guard current.isEmpty, !fieldWasQuoted else {
                    throw ParseError.textAfterClosingQuote(row: rows.count)
                }
                quoted = true
                fieldWasQuoted = true
            case ",":
                fields.append(current)
                current = ""
                justClosedQuote = false
                fieldWasQuoted = false
            case "\r":
                guard index + 1 < scalars.count, scalars[index + 1] == "\n" else {
                    throw ParseError.badLineTerminator(row: rows.count)
                }
                index += 1
                fields.append(current)
                guard fields.count == ExportCSV.header.count else {
                    throw ParseError.wrongFieldCount(row: rows.count, count: fields.count)
                }
                rows.append(fields)
                fields = []
                current = ""
                justClosedQuote = false
                fieldWasQuoted = false
            case "\n":
                throw ParseError.badLineTerminator(row: rows.count)
            default:
                guard !justClosedQuote else {
                    throw ParseError.textAfterClosingQuote(row: rows.count)
                }
                current.unicodeScalars.append(scalar)
            }
            index += 1
        }
        if quoted { throw ParseError.unclosedQuote }
        if !current.isEmpty || !fields.isEmpty {
            fields.append(current)
            throw ParseError.wrongFieldCount(row: rows.count, count: fields.count)
        }
        return rows
    }

    /// Field value by column name, using `ExportCSV.header` for the mapping.
    static func value(_ column: String, in row: [String]) -> String? {
        guard let index = ExportCSV.header.firstIndex(of: column),
              index < row.count
        else { return nil }
        return row[index]
    }
}
