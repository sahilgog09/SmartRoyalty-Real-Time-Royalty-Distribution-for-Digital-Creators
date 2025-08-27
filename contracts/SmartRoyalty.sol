// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


/**
 * @title SmartRoyalty
 * @notice Pull-based royalty splitter with per-content managers.
 * - Global owner can assign a manager per contentId.
 * - Manager (or owner) configures splits for that contentId.
 * - Funders deposit ETH to a contentId; recipients withdraw later.
 */
contract SmartRoyalty is Ownable, ReentrancyGuard, Pausable {
    // ===== Constants =====
    uint256 public constant BASIS_POINTS = 10_000;


    // ===== Types =====
    struct Royalty {
        address recipient; // 20 bytes
        uint16 shareBps;   // 2 bytes (0..10000)
        // 10 bytes padding -> 1 slot total
    }

    // ===== Storage =====
    // contentId => splits
    mapping(uint256 => Royalty[]) private _splits;

    // recipient => owed amount (pull model)
    mapping(address => uint256) public pendingWithdrawals;

    // contentId => manager allowed to configure/update that content
    mapping(uint256 => address) public contentOwner;

    // ===== Custom errors (cheaper than strings) =====
    error ZeroAddress();
    error InvalidShare();
    error LengthMismatch();
    error NoRecipients();
    error SharesTotalInvalid();
    error NotConfigured();
    error NoFunds();
    error Unauthorized();
    error RecipientNotFound();
    error DuplicateRecipient();

    // ===== Events =====
    event ContentOwnerSet(uint256 indexed contentId, address indexed manager);
    event RoyaltiesSet(uint256 indexed contentId);
    event RoyaltiesFunded(uint256 indexed contentId, uint256 amount, uint256 distributed, uint256 remainder);
    event RecipientUpdated(uint256 indexed contentId, address indexed oldRecipient, address indexed newRecipient);
    event Withdrawal(address indexed account, address indexed to, uint256 amount);

    // ===== Modifiers =====
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

    // ===== Admin controls =====
    function setContentOwner(uint256 contentId, address manager) external onlyOwner {
        if (manager == address(0)) revert ZeroAddress();
        contentOwner[contentId] = manager;
        emit ContentOwnerSet(contentId, manager);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // ===== Configure splits =====
    function setRoyalties(
        uint256 contentId,
        address[] calldata recipients,
        uint256[] calldata sharesBps
    ) external onlyManager(contentId) validInput(recipients, sharesBps) whenNotPaused {
        delete _splits[contentId];
        Royalty[] storage list = _splits[contentId];

        uint256 total;
        uint256 len = recipients.length;

        for (uint256 i; i < len; ) {
            address r = recipients[i];
            uint256 s = sharesBps[i];

            if (r == address(0)) revert ZeroAddress();
            if (s == 0 || s > BASIS_POINTS) revert InvalidShare();

            // prevent duplicates (O(n^2) but n is typically small)
            for (uint256 j; j < i; ) {
                if (recipients[j] == r) revert DuplicateRecipient();
                unchecked { ++j; }
            }

            list.push(Royalty(r, uint16(s)));
            total += s;

            unchecked { ++i; }
        }

        if (total != BASIS_POINTS) revert SharesTotalInvalid();
        emit RoyaltiesSet(contentId);
    }

    // ===== Funding (pull-based distribution) =====
    function fundRoyalties(uint256 contentId) external payable whenNotPaused {
        uint256 amount = msg.value;
        if (amount == 0) revert NoFunds();

        Royalty[] storage list = _splits[contentId];
        uint256 len = list.length;
        if (len == 0) revert NotConfigured();

        uint256 distributed;
        for (uint256 i; i < len; ) {
            Royalty storage r = list[i];
            uint256 payout = (amount * r.shareBps) / BASIS_POINTS;
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

    // ===== Withdrawals =====
    function withdrawRoyalties() external nonReentrant whenNotPaused {
        _withdrawTo(msg.sender, msg.sender);
    }

    function withdrawTo(address to) external nonReentrant whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        _withdrawTo(msg.sender, to);
    }

    function _withdrawTo(address from, address to) internal {
        uint256 bal = pendingWithdrawals[from];
        if (bal == 0) revert NoFunds();
        pendingWithdrawals[from] = 0;

        (bool ok, ) = to.call{value: bal}("");
        require(ok, "Withdraw failed");
        emit Withdrawal(from, to, bal);
    }

    // ===== Views =====
    function getRoyalties(uint256 contentId)
        external
        view
        returns (address[] memory recipients, uint256[] memory sharesBps)
    {
        Royalty[] storage list = _splits[contentId];
        uint256 len = list.length;

        recipients = new address[](len);
        sharesBps = new uint256[](len);

        for (uint256 i; i < len; ) {
            Royalty storage r = list[i];
            recipients[i] = r.recipient;
            sharesBps[i] = r.shareBps;
            unchecked { ++i; }
        }
    }

    /// @notice Pure preview of payouts for a given amount at current config.
    function previewPayouts(uint256 contentId, uint256 amount)
        external
        view
        returns (address[] memory recipients, uint256[] memory payouts, uint256 remainder)
    {
        Royalty[] storage list = _splits[contentId];
        uint256 len = list.length;
        if (len == 0) revert NotConfigured();

        recipients = new address[](len);
        payouts = new uint256[](len);

        uint256 distributed;
        for (uint256 i; i < len; ) {
            Royalty storage r = list[i];
            uint256 p = (amount * r.shareBps) / BASIS_POINTS;
            recipients[i] = r.recipient;
            payouts[i] = p;
            distributed += p;
            unchecked { ++i; }
        }
        remainder = amount - distributed;
    }

    // ===== Maintenance =====
    function updateRecipient(
        uint256 contentId,
        address oldRecipient,
        address newRecipient
    ) external whenNotPaused {
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
                // prevent accidental duplication
                if (newRecipient != oldRecipient) {
                    for (uint256 j; j < len; ) {
                        if (list[j].recipient == newRecipient) revert DuplicateRecipient();
                        unchecked { ++j; }
                    }
                }

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
