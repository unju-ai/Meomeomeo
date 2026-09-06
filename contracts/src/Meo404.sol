// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Meo404 — Meo Meo Meo ERC-404-style collection
/// @notice Hybrid fungible token + NFT. Classic 404 pairing:
///         **1 whole token (1e18 units) ↔ 1 NFT**.
///
/// Minting is restricted to a **minter role**. The intended minter is a
/// hosted claim backend that verifies a Roblox purchase entitlement and
/// then calls `mintFromEntitlement`. Private keys must never live in the
/// Roblox place file.
///
/// This is an ERC-404-*style* implementation (pairing rule + dual interfaces),
/// not a byte-for-byte Pandora ERC-404. ERC-20 transfers use `transfer` /
/// `transferFrom`. ERC-721 transfers use `transferFromNFT` / `safeTransferFrom`.
contract Meo404 {
    uint256 public constant UNITS_PER_NFT = 1e18;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    address public owner;
    string public baseURI;

    mapping(address => bool) public isMinter;
    mapping(bytes32 => bool) public entitlementUsed;

    uint256 public totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public nextTokenId = 1;
    mapping(uint256 => address) private _ownerOf;
    mapping(address => uint256[]) private _owned;
    mapping(uint256 => uint256) private _ownedIndex;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event ERC721Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event NFTApproval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event MinterUpdated(address indexed account, bool allowed);
    event EntitlementMinted(bytes32 indexed entitlementId, address indexed to, uint256 tokenId);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error NotMinter();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error EntitlementAlreadyUsed();
    error NotTokenOwner();
    error NotAuthorized();
    error InvalidToken();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyMinter() {
        if (!isMinter[msg.sender] && msg.sender != owner) revert NotMinter();
        _;
    }

    constructor(string memory name_, string memory symbol_, address owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        name = name_;
        symbol = symbol_;
        owner = owner_;
        isMinter[owner_] = true;
        emit OwnershipTransferred(address(0), owner_);
        emit MinterUpdated(owner_, true);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setMinter(address account, bool allowed) external onlyOwner {
        if (account == address(0)) revert ZeroAddress();
        isMinter[account] = allowed;
        emit MinterUpdated(account, allowed);
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    /// @notice Idempotent mint: one entitlement id → one whole token + one NFT.
    /// @dev Hosted backend should pass keccak256(purchaseId) or an equivalent unique id.
    function mintFromEntitlement(address to, bytes32 entitlementId)
        external
        onlyMinter
        returns (uint256 tokenId)
    {
        if (to == address(0)) revert ZeroAddress();
        if (entitlementUsed[entitlementId]) revert EntitlementAlreadyUsed();
        entitlementUsed[entitlementId] = true;

        _addUnits(to, UNITS_PER_NFT);
        // Sync mints exactly one NFT because we crossed a whole-token boundary.
        tokenId = _owned[to][_owned[to].length - 1];
        emit EntitlementMinted(entitlementId, to, tokenId);
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function nftBalanceOf(address account) public view returns (uint256) {
        return _owned[account].length;
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _ownerOf[tokenId];
        if (tokenOwner == address(0)) revert InvalidToken();
        return tokenOwner;
    }

    function tokenOfOwnerByIndex(address account, uint256 index) external view returns (uint256) {
        if (index >= _owned[account].length) revert InvalidToken();
        return _owned[account][index];
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (_ownerOf[tokenId] == address(0)) revert InvalidToken();
        return string.concat(baseURI, _toString(tokenId));
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transferUnits(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed < amount) revert InsufficientAllowance();
            if (allowed != type(uint256).max) {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transferUnits(from, to, amount);
        return true;
    }

    function approveNFT(address approved, uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        if (msg.sender != tokenOwner && !isApprovedForAll[tokenOwner][msg.sender]) {
            revert NotAuthorized();
        }
        getApproved[tokenId] = approved;
        emit NFTApproval(tokenOwner, approved, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Move a specific NFT and exactly `UNITS_PER_NFT` fungible units with it.
    function transferFromNFT(address from, address to, uint256 tokenId) public {
        if (to == address(0)) revert ZeroAddress();
        address tokenOwner = ownerOf(tokenId);
        if (tokenOwner != from) revert NotTokenOwner();
        if (
            msg.sender != from && !isApprovedForAll[from][msg.sender] && getApproved[tokenId] != msg.sender
        ) {
            revert NotAuthorized();
        }
        delete getApproved[tokenId];
        _removeOwned(from, tokenId);
        _balances[from] -= UNITS_PER_NFT;
        _balances[to] += UNITS_PER_NFT;
        _addOwned(to, tokenId);
        emit Transfer(from, to, UNITS_PER_NFT);
        emit ERC721Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFromNFT(from, to, tokenId);
        if (to.code.length > 0) {
            // Minimal ERC721Receiver check; skip if the recipient has no code.
            (bool ok, bytes memory data) = to.call(
                abi.encodeWithSignature(
                    "onERC721Received(address,address,uint256,bytes)", msg.sender, from, tokenId, ""
                )
            );
            require(
                ok && data.length == 32 && abi.decode(data, (bytes4)) == 0x150b7a02,
                "Meo404: unsafe recipient"
            );
        }
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165
            || interfaceId == 0x80ac58cd // ERC721
            || interfaceId == 0x5b5e139f // ERC721Metadata
            || interfaceId == 0x36372b07; // ERC20
    }

    function _transferUnits(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (_balances[from] < amount) revert InsufficientBalance();
        _setBalance(from, _balances[from] - amount);
        _setBalance(to, _balances[to] + amount);
        emit Transfer(from, to, amount);
    }

    function _addUnits(address to, uint256 amount) internal {
        totalSupply += amount;
        _setBalance(to, _balances[to] + amount);
        emit Transfer(address(0), to, amount);
    }

    /// @dev Keep NFT count == floor(erc20Balance / 1e18).
    function _setBalance(address account, uint256 newBalance) internal {
        _balances[account] = newBalance;
        uint256 desired = newBalance / UNITS_PER_NFT;
        while (_owned[account].length > desired) {
            uint256 id = _owned[account][_owned[account].length - 1];
            _removeOwned(account, id);
            emit ERC721Transfer(account, address(0), id);
        }
        while (_owned[account].length < desired) {
            uint256 id = nextTokenId++;
            _addOwned(account, id);
            emit ERC721Transfer(address(0), account, id);
        }
    }

    function _addOwned(address account, uint256 tokenId) internal {
        _ownedIndex[tokenId] = _owned[account].length;
        _owned[account].push(tokenId);
        _ownerOf[tokenId] = account;
    }

    function _removeOwned(address account, uint256 tokenId) internal {
        uint256 index = _ownedIndex[tokenId];
        uint256 last = _owned[account].length - 1;
        if (index != last) {
            uint256 lastId = _owned[account][last];
            _owned[account][index] = lastId;
            _ownedIndex[lastId] = index;
        }
        _owned[account].pop();
        delete _ownedIndex[tokenId];
        delete _ownerOf[tokenId];
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
