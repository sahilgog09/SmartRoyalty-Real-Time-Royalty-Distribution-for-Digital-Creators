// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SmartRoyalty
 * @dev Simple ETH royalty splitter for creators and collaborators using pull-payment pattern
 * @notice Send revenue to the contract, then beneficiaries withdraw their share proportionally
 */
contract SmartRoyalty {
    // State
    address public owner;
    uint256 public totalShares;       // Sum of all beneficiary shares
    uint256 public totalReleased;     // Total ETH already withdrawn

    address[] public payees;          // List of beneficiaries

    mapping(address => uint256) public shares;      // beneficiary => share units
    mapping(address => uint256) public released;    // beneficiary => total withdrawn

    // Events
    event PaymentReceived(address indexed from, uint256 amount);
    event PaymentReleased(address indexed to, uint256 amount);
    event PayeeAdded(address indexed account, uint256 shares);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address[] memory _payees, uint256[] memory _shares) payable {
        require(_payees.length == _shares.length, "Length mismatch");
        require(_payees.length > 0, "No payees");

        owner = msg.sender;

        for (uint256 i = 0; i < _payees.length; i++) {
            _addPayee(_payees[i], _shares[i]);
        }
    }

    /**
     * @dev Add a new royalty payee (only owner, cannot change existing)
     * @param account Address of the payee
     * @param shareUnits Share units assigned to the payee
     */
    function addPayee(address account, uint256 shareUnits) external onlyOwner {
        _addPayee(account, shareUnits);
    }

    function _addPayee(address account, uint256 shareUnits) internal {
        require(account != address(0), "Zero address");
        require(shareUnits > 0, "Shares are 0");
        require(shares[account] == 0, "Payee exists");

        payees.push(account);
        shares[account] = shareUnits;
        totalShares += shareUnits;

        emit PayeeAdded(account, shareUnits);
    }

    /**
     * @dev Receive plain ETH as royalty pool
     */
    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    /**
     * @dev Fallback function to receive ETH
     */
    fallback() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    /**
     * @dev Total ETH held by contract (including already released)
     */
    function totalReceived() public view returns (uint256) {
        return address(this).balance + totalReleased;
    }

    /**
     * @dev Compute pending payment for an account
     * @param account Beneficiary address
     */
    function releasable(address account) public view returns (uint256) {
        uint256 totalIncome = totalReceived();
        uint256 accountShare = (totalIncome * shares[account]) / totalShares;
        return accountShare - released[account];
    }

    /**
     * @dev Release pending royalties for the caller
     */
    function release() external {
        _release(msg.sender);
    }

    /**
     * @dev Owner can trigger release for any beneficiary
     * @param account Beneficiary address
     */
    function releaseTo(address account) external onlyOwner {
        _release(account);
    }

    function _release(address account) internal {
        require(shares[account] > 0, "No shares");

        uint256 payment = releasable(account);
        require(payment > 0, "Nothing to release");

        released[account] += payment;
        totalReleased += payment;

        (bool ok, ) = payable(account).call{value: payment}("");
        require(ok, "Transfer failed");

        emit PaymentReleased(account, payment);
    }

    /**
     * @dev Get number of payees
     */
    function payeesCount() external view returns (uint256) {
        return payees.length;
    }

    /**
     * @dev Transfer contract ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }
}
