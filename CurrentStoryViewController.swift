//
//  CurrentStoryViewController.swift
//  Hebat
//
//  Created by mohamed hashem on 29/11/2020.
//  Copyright © 2020 mohamed hashem. All rights reserved.
//

import UIKit
import ImageSlideshow
import RxSwift

class CurrentStoryViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var progressCollectionView: UICollectionView!
    @IBOutlet weak var imageSliderView: ImageSlideshow!
    @IBOutlet weak var userProfileButton: UIButton!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var userDateOrTalentedLabel: UILabel!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var saveImageStoryButton: UIButton!
    @IBOutlet weak var messageTextFeild: UITextField!
    
    var fromNotification = false
    var photos: [FeedStories.Photos] = []
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
    var showStoryID: Int?
    var isLiked = false
    var currentIndex: Int = 0
    
    var slideshowTimer: Timer?
    let transparentView = UIView()
    let tableView = UITableView()
    var friendsAre: FollowingModel?
    var shareTo: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if showStoryID != nil {
            showStory() 
        }
        
//        tableView.delegate = self
//        tableView.dataSource = self
//        tableView.register(UINib(nibName: "AllFriendTableViewCell", bundle: nil), forCellReuseIdentifier: "AllFriendTableViewCell")
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
        //self.addTransparentView(frames: self.messageTextFeild.frame)
        imageSliderView.pauseTimer()
        pauseLayer(layer: sharpLayer)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        self.removeTransparentView()
        self.imageSliderView.unpauseTimer()
        self.resumeLayer(layer: self.sharpLayer)
    }
    override open var prefersStatusBarHidden: Bool {
        return true
    }

    func addTransparentView(frames: CGRect) {
        let window = UIApplication.shared.keyWindow
        transparentView.frame = window?.frame ?? self.view.frame
        self.view.addSubview(transparentView)

        tableView.frame = CGRect(x: frames.origin.x, y: frames.origin.y + frames.height, width: 200.0, height: 0)
        self.view.addSubview(tableView)
        tableView.layer.cornerRadius = 10

        transparentView.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        tableView.reloadData()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(removeTransparentView))
        transparentView.addGestureRecognizer(tapGesture)
        transparentView.alpha = 0.5
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: .curveEaseInOut, animations: {
            self.transparentView.alpha = 0.5
            self.tableView.frame = CGRect(x: (self.view.frame.width - frames.width) / 2,
                                          y: self.view.frame.height - (200 + frames.height + 50),
                                          width: frames.width,
                                          height: 200)
        }, completion: nil)
    }

    @objc func removeTransparentView() {
        let frames = messageTextFeild.frame
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: .curveEaseInOut, animations: {
            self.transparentView.alpha = 0
            self.tableView.frame = CGRect(x: frames.origin.x, y: frames.origin.y + frames.height, width: frames.width, height: 0)
        }, completion: nil)
    }
    
    @objc func handleSliderSwipe(recognizer: UISwipeGestureRecognizer) {
        if recognizer.direction == .down {
            if fromNotification {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let rootViewController = storyboard.instantiateInitialViewController()
                rootViewController?.modalPresentationStyle = .fullScreen
                if rootViewController != nil {
                    self.present(rootViewController!, animated: false)
                }
                //self.presentEventTypeView(storyboardName: "Main", viewControllerID: "HomeTabBarController")
            } else {
                dismiss(animated: true, completion: nil)
            }
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
        if self.fromNotification {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let rootViewController = storyboard.instantiateInitialViewController()
            rootViewController?.modalPresentationStyle = .fullScreen
            if rootViewController != nil {
                self.present(rootViewController!, animated: false)
            }
            //self.presentEventTypeView(storyboardName: "Main", viewControllerID: "HomeTabBarController")
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func showStory() {
        guard let storyID = showStoryID else {
            return
        }
        HebatEndPoints.shared
            .provider.rx
            .request(.showStory(storyID: storyID))
            .filterSuccessfulStatusCodes()
            .timeout(.seconds(20), scheduler: MainScheduler.instance)
            .retry(2)
            .map(ShowStory.self)
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
    
    @IBAction func pressedToSaveStory(_ sender: UIButton) {
        guard let storyID = StoryID, currentPhotoID < photos.count else {
            return
        }
        
        HebatEndPoints.shared
            .provider.rx
            .request(.saveStory(photo_id: photos[currentPhotoID].id , story_id: storyID))
            .filterSuccessfulStatusCodes()
            .timeout(.seconds(20), scheduler: MainScheduler.instance)
            .retry(2)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { response in
                self.isLiked = !self.isLiked
                self.isLiked ? self.saveImageStoryButton.setImage(UIImage(named: "featuredy"), for: .normal) : self.saveImageStoryButton.setImage(UIImage(named: "feature"), for: .normal)
            }) { error in
                self.saveImageStoryButton.setImage(UIImage(named: "featuredy"), for: .normal)
                PopUpAlert.showErrorToastWith(error)
                
            }.disposed(by: disposed)
    }
    
    @IBAction func sendMessagePressed(_ sender: UIButton) {
        guard let message = messageTextFeild.text,
              message != "Write a reply..",
              let currentUser = try? CurrentUser.user.value(),
              let userID = user?.id,
//              let userID = shareTo,
              let StoryIDIS = StoryID else {
            PopUpAlert.showErrorToastWith(message: "please check the data that entered is correct".localized)
            return
        }
        
        sendMessage(from_user_id: currentUser.userId ,
                    to_user_id: userID,
                    message: message,
                    file: nil,
                    share_id: StoryIDIS,
                    share_type: "story")
    }
    
    func sendMessage(from_user_id: Int, to_user_id: Int, message: String, file: [UIImage]?, share_id: Int?, share_type: String?) {
        PKHUDIndicator.showProgressView()
        HebatEndPoints.shared
            .provider.rx
            .request(.sendMessage(from_user_id: from_user_id, to_user_id: to_user_id, message: message, file: file, share_id: share_id, share_type: share_type))
            .filterSuccessfulStatusCodes()
            .timeout(.seconds(300), scheduler: MainScheduler.instance)
            .retry(2)
            .map(UserChats.self)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { response in
                PKHUDIndicator.hideBySuccessFlash()
                self.imageSliderView.unpauseTimer()
                self.resumeLayer(layer: self.sharpLayer)
                self.messageTextFeild.text = ""
                self.messageTextFeild.placeholder = "Write a reply..".localized

            }) { error in
                PKHUDIndicator.hideByErrorFlash()
                self.imageSliderView.unpauseTimer()
                self.resumeLayer(layer: self.sharpLayer)
                
            }.disposed(by: disposed)
    }

    func loadUserFollowing() {
        HebatEndPoints.shared
            .provider.rx
            .request(.getFollowings)
            .filterSuccessfulStatusCodes()
            .timeout(.seconds(20), scheduler: MainScheduler.instance)
            .retry(2)
            .map(FollowingModel.self)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { response in
                self.friendsAre = response

            }) { error in

            }.disposed(by: disposed)
    }
    
    @IBAction func dismissView(_ sender: UIButton) {
        if fromNotification {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let rootViewController = storyboard.instantiateInitialViewController()
            rootViewController?.modalPresentationStyle = .fullScreen
            if rootViewController != nil {
                self.present(rootViewController!, animated: false)
            }
            //self.presentEventTypeView(storyboardName: "Main", viewControllerID: "HomeTabBarController")
        } else {
            dismiss(animated: true, completion: nil)
        }
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
extension CurrentStoryViewController: ImageSlideshowDelegate  {
    
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
            if fromNotification {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let rootViewController = storyboard.instantiateInitialViewController()
                rootViewController?.modalPresentationStyle = .fullScreen
                if rootViewController != nil {
                    self.present(rootViewController!, animated: false)
                }
                //self.presentEventTypeView(storyboardName: "Main", viewControllerID: "HomeTabBarController")
            } else {
                dismiss(animated: true, completion: nil)
            }
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

// MARK: - table for freind slider Action
extension CurrentStoryViewController:  UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friendsAre?.following_data.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "AllFriendTableViewCell", for: indexPath) as? AllFriendTableViewCell else {
            fatalError()
        }
        cell.nameLabel.text = friendsAre?.following_data[indexPath.row].user.name ?? ""
        let image = friendsAre?.following_data[indexPath.row].user.path
        cell.userImage.loadImage(urlString: image ?? "")
        cell.talentedLabel.text = friendsAre?.following_data[indexPath.row].user.talent ?? ""
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let text = messageTextFeild.text ?? ""
        messageTextFeild.text = text + " " + (friendsAre?.following_data[indexPath.row].user.name ?? "").replacingOccurrences(of: " ", with: "") + " "
        shareTo = friendsAre?.following_data[indexPath.row].user.id ?? user?.id
        removeTransparentView()
    }
}
