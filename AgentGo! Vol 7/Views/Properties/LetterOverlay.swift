import SwiftUI

struct LetterOverlay: View {
    let letter: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.surfaceFor(colorScheme: colorScheme))
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .stroke(Color.borderFor(colorScheme: colorScheme), lineWidth: 1)
                )
                .shadow(radius: 5)
            
            Text(letter)
                .font(.title2.bold())
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
    }
} 