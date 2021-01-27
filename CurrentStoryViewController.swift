//
//
//  Created by mohamed hashem on 29/11/2020.
//  Copyright © 2020 mohamed hashem. All rights reserved.
//

import UIKit
import ImageSlideshow
import RxSwift

class YourClass: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var progressCollectionView: UICollectionView!
    @IBOutlet weak var imageSliderView: ImageSlideshow!
    @IBOutlet weak var userProfileButton: UIButton!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var userDateOrTalentedLabel: UILabel!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var saveImageStoryButton: UIButton!
    @IBOutlet weak var messageTextFeild: UITextField!
    
    var photos: [FeedStories.Photos] = [] // your model
    var StoryID: Int?
    var user: FeedStories.User?
    var kingfisherSource: [KingfisherSource] = [] {
        didSet {
            progressCollectionView.reloadData()
        }
    }
    let sharpLayer = CAShapeLayer()
    var newViewForProgress: UIView!
    var pauseIs = false
    private let disposed = DisposeBag()
    var currentPhotoID: Int = 0
    var slideshowTimer: Timer?
  
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if showStoryID != nil {
            showStory() 
        }
  
        loadUserFollowing()

        userProfileButton.isHidden = true
        userImage.loadImage(urlString: user?.path ?? "")
        userNameLabel.text = user?.name
        userDateOrTalentedLabel.text = user?.talent

        let tapRecognizer = UILongPressGestureRecognizer(target: self,
                                                         action: #selector(handleSliderTap(recognizer:)))
        let swipeRecognizer = UISwipeGestureRecognizer(target: self,
                                                       action: #selector(handleSliderSwipe(recognizer:)))
        swipeRecognizer.direction = .down
        tapRecognizer.minimumPressDuration = 0.5
        tapRecognizer.numberOfTouchesRequired = 1
        imageSliderView.addGestureRecognizer(tapRecognizer)
        imageSliderView.addGestureRecognizer(swipeRecognizer)
        
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField.text == "Write a reply.." {
            textField.text = ""
        }
        imageSliderView.pauseTimer()
        pauseLayer(layer: sharpLayer)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        self.removeTransparentView()
        self.imageSliderView.unpauseTimer()
        self.resumeLayer(layer: self.sharpLayer)
    }
    
    @objc func handleSliderSwipe(recognizer: UISwipeGestureRecognizer) {
        if recognizer.direction == .down {
          dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func handleSliderTap(recognizer: UITapGestureRecognizer) {
        switch recognizer.state {
        case .began:
            imageSliderView.pauseTimer()
            pauseLayer(layer: sharpLayer)
            
        case .changed:
            imageSliderView.pauseTimer()
            pauseLayer(layer: sharpLayer)
            
        case .ended:
            imageSliderView.unpauseTimer()
            resumeLayer(layer: sharpLayer)
            
        default:
            imageSliderView.unpauseTimer()
            resumeLayer(layer: sharpLayer)
        }
    }
    
    func creatSlider() {
        imageSliderView.slideshowInterval = 7.0
        imageSliderView.contentScaleMode = UIViewContentMode.scaleAspectFit
        imageSliderView.zoomEnabled = true
        imageSliderView.pageIndicator = nil
        imageSliderView.nextPage(animated: true)
        imageSliderView.delegate = self
        
        photos.forEach { photo in
            if let imageSource = KingfisherSource(urlString: photo.path) {
                kingfisherSource.append(imageSource)
            }
        }
        
        if photos.count == 1 {
            slideshowTimer = Timer.scheduledTimer(timeInterval: 7, target: self, selector: #selector(self.slideshowTick), userInfo: nil, repeats: true)
        }
        
        imageSliderView.activityIndicator =  DefaultActivityIndicator(style: .white, color: #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1))
        imageSliderView.setImageInputs(kingfisherSource)
        progressCollectionView.reloadData()
    }
    
    @objc func slideshowTick() {
         self.dismiss(animated: true, completion: nil)
    }
    
    private func showStory() {
        guard let storyID = showStoryID else {
            return
        }
        DataBase.shared
            .provider.rx
            .request(.showStory(storyID: storyID))
            .filterSuccessfulStatusCodes()
            .timeout(.seconds(20), scheduler: MainScheduler.instance)
            .retry(2)
            .map(yourModel.self)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { response in
                guard let storyIs = response.story else {
                    return
                }
                self.photos = storyIs.photos
                self.StoryID = storyIs.id
                self.user = storyIs.user
                
                self.creatSlider()
                
                self.userProfileButton.isHidden = true
                self.userImage.loadImage(urlString: self.user?.path ?? "")
                self.userNameLabel.text = self.user?.name
                self.userDateOrTalentedLabel.text = self.user?.talent
                
            }) { error in
                PopUpAlert.showErrorToastWith(error)
                
            }.disposed(by: disposed)
    }
   
    @IBAction func dismissView(_ sender: UIButton) {
       dismiss(animated: true, completion: nil)
    }
}

// MARK: - CollectionViewDataSource, Delegate
extension CurrentStoryViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return kingfisherSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "progressScrollCell", for: indexPath) as? ProgressStoryCollectionViewCell else {
            fatalError()
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        if indexPath.row == 0 {
            if let currentCell = cell as? ProgressStoryCollectionViewCell  {
                drawingProgressView(start: CGPoint(x: 0.0,
                                                   y: currentCell.drawingProgressViewCell.frame.height / 2.0),
                                    end: CGPoint(x: currentCell.frame.width - 6,
                                                 y: currentCell.drawingProgressViewCell.frame.height / 2.0),
                                    content: currentCell)
            }
        }
    }
}

// MARK: - CollectionView DelegateFlowLayout
extension CurrentStoryViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: progressCollectionView.frame.size.width / CGFloat(kingfisherSource.count), height: progressCollectionView.frame.size.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
}

// MARK: - animation slider Action
extension YourClass: ImageSlideshowDelegate  {
    
    func pauseLayer(layer: CALayer) {
        let pausedTime: CFTimeInterval = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0.0
        layer.timeOffset = pausedTime
        
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }
    
    func resumeLayer(layer: CALayer) {
        layer.speed = 1.0
        layer.timeOffset = 0.0
        layer.beginTime = 0.0
        
        if photos.count == 1 {
            slideshowTimer = Timer.scheduledTimer(timeInterval: 7, target: self, selector: #selector(self.slideshowTick), userInfo: nil, repeats: true)
        }
        
        let index = IndexPath.init(item: currentIndex, section: 0)
        if index.row > 0, index.row < kingfisherSource.count {
            let index = IndexPath.init(item: currentIndex, section: 0)
            let currentProgressCell = self.progressCollectionView.cellForItem(at: index) as? ProgressStoryCollectionViewCell
            currentProgressCell?.drawingProgressViewCell.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        }
        
        if let currentProgressCell = self.progressCollectionView.cellForItem(at: index) as? ProgressStoryCollectionViewCell {
            drawingProgressView(start: CGPoint(x: 3.0, y: currentProgressCell.drawingProgressViewCell.frame.height / 2.0), end: CGPoint(x: currentProgressCell.drawingProgressViewCell.frame.width, y: currentProgressCell.drawingProgressViewCell.frame.height / 2.0),
                                content: currentProgressCell)
        }
    }
    
    func imageSlideshow(_ imageSlideshow: ImageSlideshow, didChangeCurrentPageTo page: Int) {
        currentIndex = page
        currentPhotoID = page
        if page == 0 {
            dismiss(animated: true, completion: nil)
        }
        let index = IndexPath.init(item: page, section: 0)
        if index.row > 0, index.row < kingfisherSource.count {
            let index = IndexPath.init(item: page - 1, section: 0)
            let currentProgressCell = self.progressCollectionView.cellForItem(at: index) as? ProgressStoryCollectionViewCell
            currentProgressCell?.drawingProgressViewCell.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        }
        
        if let currentProgressCell = self.progressCollectionView.cellForItem(at: index) as? ProgressStoryCollectionViewCell {
            drawingProgressView(start: CGPoint(x: 3.0, y: currentProgressCell.drawingProgressViewCell.frame.height / 2.0), end: CGPoint(x: currentProgressCell.drawingProgressViewCell.frame.width, y: currentProgressCell.drawingProgressViewCell.frame.height / 2.0),
                                content: currentProgressCell)
        }
    }
    
    func drawingProgressView(start: CGPoint, end: CGPoint, content: ProgressStoryCollectionViewCell) {
        if currentIndex < self.photos.count, self.photos[currentIndex].is_saved {
            self.saveImageStoryButton.setImage(#imageLiteral(resourceName: "featuredy"), for: .normal)
        } else {
            self.saveImageStoryButton.setImage(#imageLiteral(resourceName: "feature"), for: .normal)
        }
        
        let progressPath = UIBezierPath()
        if ConstantStore.sharedInstance.currentLanguage() == "ar" {
            progressPath.move(to: end)
            progressPath.addLine(to: start)
        } else {
            progressPath.move(to: start)
            progressPath.addLine(to: end)
        }

        sharpLayer.path = progressPath.cgPath
        sharpLayer.strokeColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        sharpLayer.fillColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
        sharpLayer.lineCap = .round
        sharpLayer.lineWidth = 5
        sharpLayer.strokeEnd = 0
        
        let basicAnimation = CABasicAnimation(keyPath: "strokeEnd")
        basicAnimation.toValue = 1
        basicAnimation.duration = 7
        basicAnimation.speed = 1.0
        basicAnimation.repeatCount = .infinity
        basicAnimation.fillMode = .forwards
        basicAnimation.isRemovedOnCompletion = true
        sharpLayer.add(basicAnimation, forKey: "strokeEnd")
        
        content.drawingProgressViewCell.backgroundColor = #colorLiteral(red: 0.4600716793, green: 0.4600716793, blue: 0.4600716793, alpha: 1)
        sharpLayer.frame = content.drawingProgressViewCell.frame
        content.drawingProgressViewCell.layer.addSublayer(sharpLayer)
    }
}

