import UIKit

public class ConfirmYourBidArtsyLoginViewController: UIViewController {

    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!

    @IBOutlet var confirmCredentialsButton: UIButton!
    lazy var provider:ReactiveMoyaProvider<ArtsyAPI> = Provider.sharedProvider

    public class func instantiateFromStoryboard() -> ConfirmYourBidArtsyLoginViewController {
        return UIStoryboard.fulfillment().viewControllerWithID(.ConfirmYourBidArtsyLogin) as ConfirmYourBidArtsyLoginViewController
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        if let nav = self.navigationController as? FulfillmentNavigationController {

            RAC(nav.bidDetails.newUser, "email") <~ emailTextField.rac_textSignal()
            RAC(nav.bidDetails.newUser, "password") <~ passwordTextField.rac_textSignal()
        }
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        emailTextField.becomeFirstResponder()
    }

    @IBAction func confirmTapped(sender: AnyObject) {

        let endpoint: ArtsyAPI = ArtsyAPI.XAuth(email: emailTextField.text, password: passwordTextField.text)

        provider.request(endpoint, method:.GET, parameters: endpoint.defaultParameters).filterSuccessfulStatusCodes().mapJSON().subscribeNext({ [weak self] (accessTokenDict) -> Void in

            if let accessToken = accessTokenDict["access_token"] as? String {
                self?.setupNavProviderWithToken(accessToken)

                self?.fulfilmentNav()?.updateUserCredentials()?.subscribeNext({ [weak self] (accessTokenDict) -> Void in
                    self?.checkForCreditCard()
                    return
                })
                
            }
        }, error: { (error) -> Void in
                println("Error logging in: \(error.localizedDescription)")
        })
    }

    func setupNavProviderWithToken(token: String) {

        let newEndpointsClosure = { (target: ArtsyAPI, method: Moya.Method, parameters: [String: AnyObject]) -> Endpoint<ArtsyAPI> in
            var endpoint: Endpoint<ArtsyAPI> = Endpoint<ArtsyAPI>(URL: url(target), sampleResponse: .Success(200, target.sampleData), method: method, parameters: parameters)

            return endpoint.endpointByAddingHTTPHeaderFields(["X-Access-Token": token])
        }

        let numberProvider:ReactiveMoyaProvider<ArtsyAPI> = ReactiveMoyaProvider(endpointsClosure: newEndpointsClosure, stubResponses: APIKeys.sharedKeys.stubResponses)

        self.fulfilmentNav()?.loggedInProvider = numberProvider
    }
    

    func checkForCreditCard() {
        let endpoint: ArtsyAPI = ArtsyAPI.MyCreditCards
        let authProvider = self.fulfilmentNav()?.loggedInProvider
        authProvider?.request(endpoint, method:.GET, parameters: endpoint.defaultParameters).filterSuccessfulStatusCodes().mapJSON().mapToObjectArray(Card.self).subscribeNext({ [weak self] (cards) -> Void in

            if countElements(cards as [Card]) > 0 {
                self?.performSegue(.EmailLoginConfirmedHighestBidder)
            } else {
                self?.performSegue(.ArtsyUserHasNotRegisteredCard)
            }
            
        }, error: { [weak self] (error) -> Void in
                println("error, the pin is likely wrong")
                return
        })
    }
}

private extension  ConfirmYourBidArtsyLoginViewController {

    @IBAction func dev_hasCardTapped(sender: AnyObject) {
        self.performSegue(.EmailLoginConfirmedHighestBidder)
    }

    @IBAction func dev_noCardFoundTapped(sender: AnyObject) {
        self.performSegue(.ArtsyUserHasNotRegisteredCard)
    }

}