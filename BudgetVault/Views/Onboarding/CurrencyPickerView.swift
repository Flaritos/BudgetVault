import SwiftUI

struct CurrencyPickerView: View {
    @Binding var selectedCurrency: String
    @State private var searchText = ""

    private var filteredCurrencies: [(code: String, name: String, symbol: String, flag: String)] {
        let filtered = searchText.isEmpty ? Self.currencies : Self.currencies.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return filtered
    }

    var body: some View {
        List {
            ForEach(filteredCurrencies, id: \.code) { currency in
                Button {
                    selectedCurrency = currency.code
                } label: {
                    HStack {
                        Text(currency.flag)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(currency.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text("\(currency.code) (\(currency.symbol))")
                                .font(.caption)
                                .foregroundStyle(BudgetVaultTheme.titanium300)
                        }
                        Spacer()
                        if selectedCurrency == currency.code {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BudgetVaultTheme.accentSoft)
                        }
                    }
                }
                .accessibilityLabel("\(currency.name), \(currency.code)")
                .accessibilityAddTraits(selectedCurrency == currency.code ? .isSelected : [])
                .listRowBackground(BudgetVaultTheme.chamberDeep)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BudgetVaultTheme.navyDark)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search currencies")
    }

    static let currencies: [(code: String, name: String, symbol: String, flag: String)] = [
        ("USD", "US Dollar", "$", "🇺🇸"),
        ("EUR", "Euro", "€", "🇪🇺"),
        ("GBP", "British Pound", "£", "🇬🇧"),
        ("JPY", "Japanese Yen", "¥", "🇯🇵"),
        ("CAD", "Canadian Dollar", "CA$", "🇨🇦"),
        ("AUD", "Australian Dollar", "A$", "🇦🇺"),
        ("CHF", "Swiss Franc", "CHF", "🇨🇭"),
        ("CNY", "Chinese Yuan", "¥", "🇨🇳"),
        ("INR", "Indian Rupee", "₹", "🇮🇳"),
        ("MXN", "Mexican Peso", "MX$", "🇲🇽"),
        ("BRL", "Brazilian Real", "R$", "🇧🇷"),
        ("KRW", "South Korean Won", "₩", "🇰🇷"),
        ("SEK", "Swedish Krona", "kr", "🇸🇪"),
        ("NOK", "Norwegian Krone", "kr", "🇳🇴"),
        ("DKK", "Danish Krone", "kr", "🇩🇰"),
        ("NZD", "New Zealand Dollar", "NZ$", "🇳🇿"),
        ("SGD", "Singapore Dollar", "S$", "🇸🇬"),
        ("HKD", "Hong Kong Dollar", "HK$", "🇭🇰"),
        ("TRY", "Turkish Lira", "₺", "🇹🇷"),
        ("ZAR", "South African Rand", "R", "🇿🇦"),
        ("PLN", "Polish Zloty", "zł", "🇵🇱"),
        ("THB", "Thai Baht", "฿", "🇹🇭"),
        ("PHP", "Philippine Peso", "₱", "🇵🇭"),
        ("CZK", "Czech Koruna", "Kč", "🇨🇿"),
        ("ILS", "Israeli Shekel", "₪", "🇮🇱"),
        ("CLP", "Chilean Peso", "CL$", "🇨🇱"),
        ("ARS", "Argentine Peso", "AR$", "🇦🇷"),
        ("COP", "Colombian Peso", "CO$", "🇨🇴"),
        ("EGP", "Egyptian Pound", "E£", "🇪🇬"),
        ("NGN", "Nigerian Naira", "₦", "🇳🇬"),
    ]
}
