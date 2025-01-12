import SwiftUI

struct PropertiesContentView: View {
    let properties: [Property]
    @Binding var selectedLetter: String?
    @Binding var showLetterOverlay: Bool
    let sectionLetters: [String]
    let onPropertySelect: (Property) -> Void
    let onDeleteRequest: (Property) -> Void
    
    var body: some View {
        ZStack {
            PropertyListView(
                properties: properties,
                selectedLetter: $selectedLetter,
                onPropertyTap: onPropertySelect,
                onDeleteTap: onDeleteRequest
            )
            
            if showLetterOverlay, let letter = selectedLetter {
                LetterOverlay(letter: letter)
            }
            
            QuickScrollArea(
                sectionLetters: sectionLetters,
                selectedLetter: $selectedLetter,
                showLetterOverlay: $showLetterOverlay
            )
        }
    }
} 