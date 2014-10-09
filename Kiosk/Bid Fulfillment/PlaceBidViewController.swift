import UIKit

class PlaceBidViewController: UIViewController {

    dynamic var bidDollars: Int = 0

    @IBOutlet var bidAmountTextField: TextField!
    @IBOutlet var keypadContainer: KeypadContainerView!

    @IBOutlet var currentBidTitleLabel: UILabel!
    @IBOutlet var currentBidAmountLabel: UILabel!
    @IBOutlet var nextBidAmountLabel: UILabel!

    @IBOutlet var artistNameLabel: ARSerifLabel!
    @IBOutlet var artworkTitleLabel: ARSerifLabel!
    @IBOutlet var artworkPriceLabel: ARSerifLabel!

    class func instantiateFromStoryboard() -> PlaceBidViewController {
        return UIStoryboard.fulfillment().viewControllerWithID(.PlaceYourBid) as PlaceBidViewController
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
//        bidAmountTextField.becomeFirstResponder()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bidAmountTextField.shouldChangeColorWhenEditing = false
        let keypad = self.keypadContainer!.keypad!
        let bidDollarsSignal = RACObserve(self, "bidDollars")
        let bidIsZeroSignal = bidDollarsSignal.map { return ($0 as Int == 0) }

        for button in [keypad.rightButton, keypad.leftButton] {
            RAC(button, "enabled") <~ bidIsZeroSignal.notEach()
        }

        let formattedBidTextSignal = RACObserve(self, "bidDollars").map({ (bid) -> AnyObject! in
            return NSNumberFormatter.localizedStringFromNumber(bid as Int, numberStyle:.DecimalStyle)
        })

        RAC(bidAmountTextField, "text") <~ RACSignal.`if`(bidIsZeroSignal, then: RACSignal.defer{ RACSignal.`return`("") }, `else`: formattedBidTextSignal)

        keypadSignal.subscribeNext(addDigitToBid)
        deleteSignal.subscribeNext(deleteBid)
        clearSignal.subscribeNext(clearBid)

        if let nav = self.navigationController as? FulfillmentNavigationController {
            RAC(nav.bidDetails, "bidAmountCents") <~ bidDollarsSignal.map { return ($0 as Float * 100) }

            if let saleArtwork:SaleArtwork = nav.bidDetails.saleArtwork {
                let minimumNextBidSignal = RACObserve(saleArtwork, "minimumNextBidCents")
                let bidCountSignal = RACObserve(saleArtwork, "bidCount")
                let openingBidSignal = RACObserve(saleArtwork, "openingBidCents")
                let highestBidSignal = RACObserve(saleArtwork, "highestBidCents")

                RAC(currentBidTitleLabel, "text") <~ bidCountSignal.map(toCurrentBidTitleString)
                RAC(nextBidAmountLabel, "text") <~ minimumNextBidSignal.map(toNextBidString)

                RAC(currentBidAmountLabel, "text") <~ RACSignal.combineLatest([bidCountSignal, highestBidSignal, openingBidSignal]).map({
                    let tuple = $0 as RACTuple
                    let bidCount = tuple.first as? Int ?? 0
                    return (bidCount > 0 ? tuple.second : tuple.third) ?? 0
                }).map(centsToPresentableDollarsString)

                RAC(bidButton, "enabled") <~ RACSignal.combineLatest([bidDollarsSignal, minimumNextBidSignal]).map({
                    let tuple = $0 as RACTuple
                    return (tuple.first as? Int ?? 0) * 100 >= (tuple.second as? Int ?? 0)
                })

                if let artist = saleArtwork.artwork.artists?.first {
                    RAC(artistNameLabel, "text") <~ RACObserve(artist, "name")
                }

                RAC(artworkTitleLabel, "text") <~ RACObserve(saleArtwork.artwork, "title")
                RAC(artworkPriceLabel, "text") <~ RACObserve(saleArtwork.artwork, "price")
            }
        }
    }

    @IBOutlet var bidButton: Button!
    @IBAction func bidButtonTapped(sender: AnyObject) {
        self.performSegue(SegueIdentifier.ConfirmBid)
    }

    lazy var keypadSignal:RACSignal! = self.keypadContainer.keypad?.keypadSignal
    lazy var clearSignal:RACSignal!  = self.keypadContainer.keypad?.rightSignal
    lazy var deleteSignal:RACSignal! = self.keypadContainer.keypad?.leftSignal
}

/// These are for RAC only

private extension PlaceBidViewController {

    func addDigitToBid(input: AnyObject!) -> Void {
        let inputInt = input as? Int ?? 0
        let newBidDollars = (10 * self.bidDollars) + inputInt
        if (newBidDollars >= 10000000) { return }
        self.bidDollars = newBidDollars
    }

    func deleteBid(input: AnyObject!) -> Void {
        self.bidDollars = self.bidDollars/10
    }

    func clearBid(input: AnyObject!) -> Void {
        self.bidDollars = 0
    }

    func toCurrentBidTitleString(input: AnyObject!) -> AnyObject! {
        if let count = input as? Int {
            return count > 0 ? "Current Bid:" : "Opening Bid:"
        } else {
            return ""
        }
    }

    func toNextBidString(cents: AnyObject!) -> AnyObject! {
        if let dollars = NSNumberFormatter.currencyStringForCents(cents as? Int) {
            return "Enter \(dollars) or more"
        }
        return ""
    }
}
