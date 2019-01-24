import UIKit
import RxSwift

enum RegistrationIndex {
    case nameVC
    case mobileVC
    case emailVC
    case passwordVC
    case creditCardVC
    case zipCodeVC
    case confirmVC
    
    func toInt() -> Int {
        switch (self) {
            case .nameVC: return 0
            case .mobileVC: return 1
            case .emailVC: return 2
            case .passwordVC: return 2
            case .zipCodeVC: return 3
            case .creditCardVC: return 4
            case .confirmVC: return 5
        }
    }

    func shouldHightlight(_ index: RegistrationIndex) -> Bool {
        switch (self) {
        case .nameVC: return index == self
        case .mobileVC: return index == self
        case .emailVC: return [.emailVC, .passwordVC].contains(index)
        case .passwordVC: return [.emailVC, .passwordVC].contains(index)
        case .zipCodeVC: return index == self
        case .creditCardVC: return index == self
        case .confirmVC: return index == self
        }
    }
}

class RegistrationCoordinator: NSObject {
    fileprivate lazy var _currentIndex: Variable<RegistrationIndex> = {
        if (self.sale.bypassCreditCardRequirement) { // Access global state here, oops.
            return Variable(.nameVC)
        } else {
            return Variable(.mobileVC)
        }
    }()
    // sale is used only for _currentIndex, and is readwrite for unit testing purposes.
    lazy var sale: Sale! = appDelegate().sale
    var currentIndex: Observable<RegistrationIndex> {
        return _currentIndex.asObservable().distinctUntilChanged()
    }
    var storyboard: UIStoryboard!

    func viewControllerForIndex(_ index: RegistrationIndex) -> UIViewController {
        _currentIndex.value = index 
        
        switch index {
        case .nameVC:
            return storyboard.viewController(withID: .RegisterName)
        case .mobileVC:
            return storyboard.viewController(withID: .RegisterMobile)
        case .emailVC:
            return storyboard.viewController(withID: .RegisterEmail)
        case .passwordVC:
            return storyboard.viewController(withID: .RegisterPassword)
        case .zipCodeVC:
            return storyboard.viewController(withID: .RegisterPostalorZip)
        case .creditCardVC:
            if AppSetup.sharedState.disableCardReader {
                return storyboard.viewController(withID: .ManualCardDetailsInput)
            } else {
                return storyboard.viewController(withID: .RegisterCreditCard)
            }
        case .confirmVC:
            return storyboard.viewController(withID: .RegisterConfirm)
        }
    }

    func nextViewControllerForBidDetails(_ details: BidDetails, sale: Sale) -> UIViewController {
        if (sale.bypassCreditCardRequirement) {
            if notSet(details.newUser.name.value) {
                return viewControllerForIndex(.nameVC)
            }
        }
        
        if notSet(details.newUser.phoneNumber.value) {
            return viewControllerForIndex(.mobileVC)
        }

        if notSet(details.newUser.email.value) {
            return viewControllerForIndex(.emailVC)
        }

        if notSet(details.newUser.password.value) && notSet(details.bidderPIN.value) {
            return viewControllerForIndex(.passwordVC)
        }

        if notSet(details.newUser.zipCode.value) && AppSetup.sharedState.needsZipCode {
            return viewControllerForIndex(.zipCodeVC)
        }
        
        if notSet(details.newUser.creditCardToken.value) && (sale.bypassCreditCardRequirement == false) {
            return viewControllerForIndex(.creditCardVC)
        }

        return viewControllerForIndex(.confirmVC)
    }
}

private func notSet(_ string: String?) -> Bool {
    return string?.isEmpty ?? true
}
