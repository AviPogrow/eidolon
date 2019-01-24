import UIKit
import RxSwift
import Moya

@objc class BidDetails: NSObject {
    typealias DownloadImageClosure = (_ url: URL, _ imageView: UIImageView) -> ()

    // Users can type either their paddle or phone number into the UI and we have to work with either.
    // So we'll default to .paddleNumber and depending on lookup success in ConfirmYourBidViewController, we'll update.
    enum AuthNumberType {
        case paddleNumber
        case phoneNumber
    }

    let auctionID: String

    var newUser: NewUser = NewUser()
    var saleArtwork: SaleArtwork?

    var paddleNumber = Variable<String?>(nil)
    var bidderPIN = Variable<String?>(nil)
    var bidAmountCents = Variable<NSNumber?>(nil)
    var bidderID = Variable<String?>(nil)

    var authNumberType: AuthNumberType = .paddleNumber

    var setImage: DownloadImageClosure = { (url, imageView) -> () in
        imageView.sd_setImage(with: url)
    }

    init(saleArtwork: SaleArtwork?, paddleNumber: String?, bidderPIN: String?, bidAmountCents: Currency?, auctionID: String) {
        self.auctionID = auctionID
        self.saleArtwork = saleArtwork
        self.paddleNumber.value = paddleNumber
        self.bidderPIN.value = bidderPIN
        self.bidAmountCents.value = bidAmountCents as NSNumber?
    }

    /// Creates a new authenticated networking provider based on either:
    /// - User's paddle/phone # and PIN, or
    /// - User's email and password
    func authenticatedNetworking(provider: Networking) -> Observable<AuthorizedNetworking> {

        let auctionID = saleArtwork?.auctionID ?? ""

        if let _ = paddleNumber.value, let pin = bidderPIN.value {
            let newEndpointsClosure = { (target: ArtsyAuthenticatedAPI) -> Endpoint in
                // Grab existing endpoint to piggy-back off of any existing configurations being used by the sharedprovider.
                let endpoint = Networking.endpointsClosure()(target)

                let task: Task
                switch target.task {
                case .requestParameters(parameters: var params, encoding: let encoding):
                    let number = self.paddleNumber.value ?? "" // Update value from self, not anything captured by the closure.
                    params["auction_pin"] = pin // pin captured by closure is okay, we don't expect it to change once authorized.
                    params["number"] = self.authNumberType == .paddleNumber ? number : formatPhoneNumberForRegion(number)
                    params["sale_id"] = auctionID
                    task = .requestParameters(parameters: params, encoding: encoding)
                default:
                    task = target.task
                }

                return endpoint.changing(newTask: task)
            }

            let provider = OnlineProvider(endpointClosure: newEndpointsClosure, requestClosure: Networking.endpointResolver(), stubClosure: Networking.APIKeysBasedStubBehaviour, plugins: Networking.authenticatedPlugins)

            return .just(AuthorizedNetworking(provider: provider))

        } else {
            let endpoint: ArtsyAPI = ArtsyAPI.xAuth(email: newUser.email.value ?? "", password: newUser.password.value ?? "")

            return provider.request(endpoint)
                .filterSuccessfulStatusCodes()
                .mapJSON()
                .flatMap { accessTokenDict -> Observable<AuthorizedNetworking> in
                    guard let accessToken = (accessTokenDict as AnyObject)["access_token"] as? String else {
                        return Observable.error(EidolonError.couldNotParseJSON)
                    }

                    return .just(Networking.newAuthorizedNetworking(accessToken))
                }
                .logServerError(message: "Getting Access Token failed.")
        }
    }
}

extension Endpoint {
    func changing(newTask: Task) -> Endpoint {
        return Endpoint(url: url, sampleResponseClosure: sampleResponseClosure, method: method, task: newTask, httpHeaderFields: httpHeaderFields)
    }
}
