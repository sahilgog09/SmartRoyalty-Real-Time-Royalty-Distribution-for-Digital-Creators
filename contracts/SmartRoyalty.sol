// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


/**
 * @title SmartRoyalty
 * @notice Pull-based royalty splitter with per-content access control.
 * - Owner can assign a manager (contentOwner) per contentId.
 * - Manager (or owner) configures royalty splits for that contentId.
 * - Funders deposit ETH to a contentId; recipients withdraw later.
 */
contract SmartRoyalty is Ownable, ReentrancyGuard {
    // ========= Constants =========
    uint256 public constant BASIS_POINTS = 10_000;

    // ========= Types =========
    struct Royalty {
        address recipient;
        uint96 share; // gas-efficient
    }

    // ========= Storage =========
    // contentId => splits
    mapping(uint256 => Royalty[]) private _splits;

    // recipient => pending amount (pull model)
    mapping(address => uint256) public pendingWithdrawals;


    // contentId => manager allowed to configure/update that content
    mapping(uint256 => address) public contentOwner;

    // ========= Custom Errors (cheaper than strings) =========
    error ZeroAddress();
    error InvalidShare();
    error LengthMismatch();
    error NoRecipients();
    error SharesTotalInvalid();
    error NotConfigured();
    error NoFunds();
    error Unauthorized();
    error RecipientNotFound();

    // ========= Events =========
    event ContentOwnerSet(uint256 indexed contentId, address indexed manager);
    event RoyaltiesSet(uint256 indexed contentId);
    event RoyaltiesFunded(uint256 indexed contentId, uint256 amount, uint256 distributed, uint256 remainder);
    event RecipientUpdated(uint256 indexed contentId, address indexed oldRecipient, address indexed newRecipient);
    event Withdrawal(address indexed account, uint256 amount);

    // ========= Modifiers =========
    modifier onlyManager(uint256 contentId) {
        address manager = contentOwner[contentId];
        if (msg.sender != owner() && msg.sender != manager) revert Unauthorized();
        _;
    }

    modifier validInput(address[] calldata recipients, uint256[] calldata shares) {
        uint256 len = recipients.length;
        if (len == 0) revert NoRecipients();
        if (len != shares.length) revert LengthMismatch();
        _;
    }

    // ========= Admin: per-content access control =========
    /**
     * @notice Assign or change the manager for a specific contentId.
     * @dev Only contract owner can call.
     */
    function setContentOwner(uint256 contentId, address manager) external onlyOwner {
        if (manager == address(0)) revert ZeroAddress();
        contentOwner[contentId] = manager;
        emit ContentOwnerSet(contentId, manager);
    }

    // ========= Configure splits (manager or owner) =========
    function setRoyalties(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata shares
    ) external onlyManager(contentId) validInput(recipients, shares) {
        delete _splits[contentId];
        Royalty[] storage list = _splits[contentId];

        uint256 total;
        uint256 len = recipients.length;

        for (uint256 i; i < len; ) {
            address r = recipients[i];
            uint256 s = shares[i];

            if (r == address(0)) revert ZeroAddress();
            if (s == 0 || s > BASIS_POINTS) revert InvalidShare();

            list.push(Royalty(r, uint96(s)));
            total += s;

            unchecked { ++i; }
        }

        if (total != BASIS_POINTS) revert SharesTotalInvalid();
        emit RoyaltiesSet(contentId);
    }

    // ========= Funding (pull-based distribution) =========
    /**
     * @notice Fund a contentId's royalties. Credits recipients' balances.
     * @dev Any remainder from integer division is credited to the manager (or owner fallback).
     */
    function fundRoyalties(uint256 contentId) external payable {
        uint256 amount = msg.value;
        if (amount == 0) revert NoFunds();

        Royalty[] storage list = _splits[contentId];
        uint256 len = list.length;
        if (len == 0) revert NotConfigured();

        uint256 distributed;
        for (uint256 i; i < len; ) {
            Royalty storage r = list[i];
            uint256 payout = (amount * r.share) / BASIS_POINTS;
            if (payout != 0) {
                pendingWithdrawals[r.recipient] += payout;
                distributed += payout;
            }
            unchecked { ++i; }
        }

        // Handle rounding dust so nothing gets stuck
        uint256 remainder = amount - distributed;
        if (remainder != 0) {
            address mgr = contentOwner[contentId];
            pendingWithdrawals[mgr == address(0) ? owner() : mgr] += remainder;
        }

        emit RoyaltiesFunded(contentId, amount, distributed, remainder);
    }

    // ========= Withdrawals =========
    function withdrawRoyalties() external nonReentrant {
        uint256 bal = pendingWithdrawals[msg.sender];
        if (bal == 0) revert NoFunds();
        pendingWithdrawals[msg.sender] = 0;

        (bool ok, ) = msg.sender.call{value: bal}("");
        require(ok, "Withdraw failed"); // very unlikely to fail after state change
        emit Withdrawal(msg.sender, bal);
    }

    // ========= Views =========
    function getRoyalties(uint256 contentId)
        external
        view
        returns (address[] memory recipients, uint256[] memory shares)
    {
        Royalty[] storage list = _splits[contentId];
        uint256 len = list.length;

        recipients = new address[](len);
        shares = new uint256[](len);

        for (uint256 i; i < len; ) {
            Royalty storage r = list[i];
            recipients[i] = r.recipient;
            shares[i] = r.share;
            unchecked { ++i; }
        }
    }

    // ========= Maintenance =========
    /**
     * @notice Update a recipient for a given contentId.
     * @dev Callable by the old recipient, the content manager, or the contract owner.
     *      Migrates any pending balance to the new address.
     */
    function updateRecipient(
        uint256 contentId,
        address oldRecipient,
        address newRecipient
    ) external {
        if (newRecipient == address(0)) revert ZeroAddress();

        Royalty[] storage list = _splits[contentId];
        uint256 len = list.length;
        if (len == 0) revert NotConfigured();

        bool callerAuthorized = (msg.sender == oldRecipient) ||
                                (msg.sender == owner()) ||
                                (msg.sender == contentOwner[contentId]);
        if (!callerAuthorized) revert Unauthorized();

        for (uint256 i; i < len; ) {
            if (list[i].recipient == oldRecipient) {
                list[i].recipient = newRecipient;

                // migrate any credited balance
                uint256 owed = pendingWithdrawals[oldRecipient];
                if (owed != 0) {
                    pendingWithdrawals[oldRecipient] = 0;
                    pendingWithdrawals[newRecipient] += owed;
                }

                emit RecipientUpdated(contentId, oldRecipient, newRecipient);
                return;
            }
            unchecked { ++i; }
        }

        revert RecipientNotFound();
    }

    // Disallow blind ETH sends
    receive() external payable {
        revert("Use fundRoyalties()");
    }
}
