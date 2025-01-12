import SwiftUI

struct QuickScrollArea: View {
    let sectionLetters: [String]
    @Binding var selectedLetter: String?
    @Binding var showLetterOverlay: Bool
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .frame(width: 44, height: geometry.size.height)
                .contentShape(Rectangle())
                .position(x: geometry.size.width - 22, y: geometry.size.height/2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDragChange(value, in: geometry)
                        }
                        .onEnded { _ in
                            handleDragEnd()
                        }
                )
        }
    }
    
    private func handleDragChange(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        let scrollHeight = geometry.size.height * 0.5
        let initialTouchY = value.startLocation.y
        let centerY = initialTouchY - (scrollHeight / 2)
        let relativeY = value.location.y - centerY
        let letterHeight = scrollHeight / CGFloat(sectionLetters.count)
        let index = Int((relativeY / letterHeight).rounded())
        
        if index >= 0 && index < sectionLetters.count {
            selectedLetter = sectionLetters[index]
            showLetterOverlay = true
        }
    }
    
    private func handleDragEnd() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                showLetterOverlay = false
                selectedLetter = nil
            }
        }
    }
} 