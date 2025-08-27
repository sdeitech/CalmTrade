//
//  UIImage+Extension.swift
//  CalmTrade
//
//  Created by Anas Parekh on 25/08/25.
//


import UIKit
import ImageIO

// MARK: - UIImageView Extension for GIF Playback

extension UIImageView {

    /// Loads a GIF from the app bundle and configures the UIImageView to play it.
    ///
    /// - Parameters:
    ///   - name: The name of the GIF file (without the .gif extension).
    ///   - repeatCount: The number of times to repeat the animation. Use 0 for infinite loop, 1 for single playback.
    /// - Returns: The total duration of one loop of the GIF animation.
    public func loadGif(name: String, repeatCount: Int = 1) -> TimeInterval {
        // 1. Check if the GIF file exists in the bundle.
        guard let bundleURL = Bundle.main.url(forResource: name, withExtension: "gif") else {
            print("Error: GIF not found with name: \(name)")
            return 0
        }

        // 2. Create an image source from the GIF's URL.
        guard let source = CGImageSourceCreateWithURL(bundleURL as CFURL, nil) else {
            print("Error: Cannot create image source from GIF.")
            return 0
        }

        // 3. Extract frames and calculate duration.
        let frameCount = CGImageSourceGetCount(source)
        var frames: [UIImage] = []
        var totalDuration: TimeInterval = 0

        for i in 0..<frameCount {
            // Get the frame image.
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            
            // Get the duration of the frame.
            let frameDuration = getFrameDuration(from: source, at: i)
            totalDuration += frameDuration
            
            frames.append(UIImage(cgImage: cgImage))
        }

        // 4. Configure the UIImageView for animation.
        self.animationImages = frames
        self.animationDuration = totalDuration
        self.animationRepeatCount = repeatCount // Play once
        
        return totalDuration
    }

    /// Helper function to extract the duration of a single frame from a GIF source.
    private func getFrameDuration(from source: CGImageSource, at index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
            return 0.1 // Default duration
        }

        let delayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? TimeInterval
        let unclampedDelayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? TimeInterval
        
        return delayTime ?? unclampedDelayTime ?? 0.1
    }
}

// MARK: - How to Use in your UIViewController

/*
 
 // In your SplashViewController or any other ViewController:
 
 class SplashViewController: UIViewController {

     // Connect this outlet to your container view in the Storyboard.
     @IBOutlet weak var animationContainerView: UIView!

     override func viewDidAppear(_ animated: Bool) {
         super.viewDidAppear(animated)
         
         // Call the function to play the GIF.
         playGIF(named: "YourGifFileName", inContainer: animationContainerView) {
             print("GIF animation has finished!")
             // Now you can transition to the next screen.
             // self.navigateToNextScreen()
         }
     }

     /// Plays a GIF one time inside a specified container view.
     ///
     /// - Parameters:
     ///   - name: The name of the GIF file in your project.
     ///   - container: The UIView where the GIF should be displayed.
     ///   - completion: A closure that is called after the GIF has finished playing.
     func playGIF(named name: String, inContainer container: UIView, completion: (() -> Void)?) {
         // Create an image view to hold the GIF.
         let gifImageView = UIImageView()
         
         // Load the GIF and get its duration.
         let duration = gifImageView.loadGif(name: name, repeatCount: 1)
         
         // Add the image view to the container.
         container.addSubview(gifImageView)
         
         // Set up constraints to make the GIF fill the container.
         gifImageView.translatesAutoresizingMaskIntoConstraints = false
         NSLayoutConstraint.activate([
             gifImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
             gifImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
             gifImageView.topAnchor.constraint(equalTo: container.topAnchor),
             gifImageView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
         ])
         
         // Start the animation.
         gifImageView.startAnimating()
         
         // Schedule the completion handler to run after the animation duration.
         DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
             completion?()
         }
     }
 }

*/
