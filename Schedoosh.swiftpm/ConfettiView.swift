import SwiftUI
import UIKit

struct ConfettiView: View {
    let colors: [Color] = [
        .red, .blue, .green, .yellow, .orange, .purple, .pink, Color(hex: "2EFF6B", alpha: 1.0)
    ]
    
    @State private var animationTrigger = UUID()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<80, id: \.self) { i in
                    ConfettiParticle(
                        color: colors[i % colors.count],
                        index: i,
                        screenWidth: geometry.size.width,
                        screenHeight: geometry.size.height,
                        animationTrigger: animationTrigger
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Reset animation trigger when view appears to restart animations
            animationTrigger = UUID()
        }
    }
}

struct ConfettiParticle: View {
    let color: Color
    let index: Int
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let animationTrigger: UUID
    
    @State private var yOffset: CGFloat
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 0
    
    private let startX: CGFloat
    private let delay: Double
    private let duration: Double
    private let targetXOffset: CGFloat
    private let targetRotation: Double
    private let finalY: CGFloat
    private let size: CGFloat
    private let initialOpacity: Double
    
    init(color: Color, index: Int, screenWidth: CGFloat, screenHeight: CGFloat, animationTrigger: UUID) {
        self.color = color
        self.index = index
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.animationTrigger = animationTrigger
        
        // Start at bottom of screen (at the bottom edge)
        self._yOffset = State(initialValue: screenHeight)
        
        // Random starting X position across screen width
        self.startX = CGFloat.random(in: 0...screenWidth)
        
        // Varied delays for staggered appearance
        self.delay = Double(index) * Double.random(in: 0.05...0.12)
        
        // Vary duration more for realistic timing - some fast, some slow
        self.duration = Double.random(in: 4.0...7.0)
        
        // More varied horizontal drift - wider range for more chaos
        self.targetXOffset = CGFloat.random(in: -350...350)
        
        // Single rotation value (not continuous) - just how much it rotates during flight
        self.targetRotation = Double.random(in: -1080...1080)
        
        // End position - far above screen
        self.finalY = -200
        
        // Vary sizes for more realism (some bigger, some smaller)
        self.size = CGFloat.random(in: 6...14)
        
        // Vary opacity for depth
        self.initialOpacity = Double.random(in: 0.7...1.0)
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(x: startX + xOffset, y: yOffset)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .id(animationTrigger) // Force view recreation when trigger changes
            .onAppear {
                startAnimation()
            }
    }
    
    private func startAnimation() {
        // Add delay before starting for staggered effect
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Make visible immediately when animation starts
            withAnimation(.linear(duration: 0.1)) {
                opacity = initialOpacity
            }
            
            // Main upward movement with easing for more natural feel
            // Include rotation as a single animation (not continuous) - rotates during flight
            withAnimation(.easeOut(duration: duration)) {
                yOffset = finalY
                xOffset = targetXOffset
                rotation = targetRotation
            }
            
            // Fade out gradually when approaching top (last 30% of journey)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.7) {
                withAnimation(.easeIn(duration: duration * 0.3)) {
                    opacity = 0.0
                }
            }
        }
    }
}
