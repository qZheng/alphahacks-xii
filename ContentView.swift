import SwiftUI

struct ContentView: View {
    @State private var items: Int = 0
    @State private var name = "Hello"
    var body: some View {
        ZStack {
            NavigationStack {
                LinearGradient(gradient: Gradient(colors: [Color.red, Color.blue]), startPoint: .leading, endPoint: .trailing
                ).edgesIgnoringSafeArea(.all)
            }
            
            VStack {
                Image(systemName: "globe")
                    .foregroundColor(.accentColor)
                Text("Hello, world")
                    .font(.largeTitle)
                
                Button("Recycle Item") {
                    items += 1
                }
                .buttonStyle(.borderedProminent)

                Image(systemName: "square.and.arrow.up.on.square.fill")
                    .foregroundColor(.accentColor)
                
                Text("\(items)")
                    .font(.title)
                DisclosureGroup(/*@START_MENU_TOKEN@*/"Group"/*@END_MENU_TOKEN@*/) {
                    /*@START_MENU_TOKEN@*//*@PLACEHOLDER=Content@*/Text("Content")/*@END_MENU_TOKEN@*/
                }
                .padding(.horizontal)
            
                TextField("Name", text: $name)
                    .padding()
                
                
            }
        }
    }
}
