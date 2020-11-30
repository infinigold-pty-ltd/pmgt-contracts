pragma solidity ^0.4.24;

import "./token/ERC20.sol";
import "./lifecycle/Mintable.sol";
import "./lifecycle/Burnable.sol";
import "./lifecycle/Pausable.sol";
import "./lifecycle/Blacklistable.sol";
import "./lifecycle/Whitelistable.sol";
import "./math/SafeMath.sol";

/**
 * @title TokenImpl
 *
 * @dev This contract is the token implementation contract encapsulating all logic for the token.
 *
 * It inherits the ERC20 contract to provide ERC20 token functionality.
 * It inherits the Mintable contract to provide mint functionality.
 * It inherits the Burnable contract to provide burn functionality.
 * It inherits the Pausable contract to provide pause normal token functionality.
 * It inherits the Blacklistable contract to restrict blacklisted accounts from sending/receiving tokens.
 * It inherits the Whitelistable contract to allow whitelisted accounts to burn their own tokens.
 */
contract TokenImpl is ERC20, Mintable, Burnable, Pausable, Blacklistable, Whitelistable {
    using SafeMath for uint256;

    /** Whether or not this contract has been initialized. */
    bool private _initialized;

    /** Descriptive attributes, for display purposes. */
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Initialize function used in place of a constructor.
     * This is required over a normal due to the constructor caveat when using proxy contracts.
     *
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param decimals The number decimals of the token
     * @param burnAddress The address for which transfers to are treated as burns
     * @param blacklist The address of the AddressList contract being used as a blacklist
     * @param whitelist The address of the AddressList contract being used as a whitelist
     */
    function initialize(
        string name,
        string symbol,
        uint8 decimals,
        address burnAddress,
        address blacklist,
        address whitelist
    ) external {
        // Assert that the contract hasn't already been initialized
        require(!_initialized);

        // Provide the account initializing the contract with access to the owner role
        super._addOwner(msg.sender);

        // Set descriptive attributes
        _name = name;
        _symbol = symbol;
        _decimals = decimals;

        // Set burn address
        super._updateBurnAddress(burnAddress);

        // Set blacklist and whitelist contract addresses
        super._updateBlacklist(blacklist);
        super._updateWhitelist(whitelist);

        // Set the initialized state to true so the contract cannot be initialized again
        _initialized = true;
    }

    /**
     * @return True if the contract has been initialized, otherwise false
     */
    function initialized() external view returns (bool) {
        return _initialized;
    }

    /**
     * @return The name of the token
     */
    function name() external view returns (string) {
        return _name;
    }

    /**
     * @return The symbol of the token
     */
    function symbol() external view returns (string) {
        return _symbol;
    }

    /**
     * @return The number of decimals of the token
     */
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Extension of the ERC20 transfer function to enforce lifecycle behaviours and support burns.
     * If `to` is the `_burnAddress` the call will be treated as a burn and the caller must be whitelisted.
     * If burning this function calls `Burnable._burn()` for additional burn logic, and emitting the Burn event.
     * If burning this function calls `ERC20._burn()` for balance/total supply logic, and emitting the Transfer event.
     *
     * @notice Transfer to the `_burnAddress` if you wish to redeem tokens.
     *
     * @param to The address to transfer to, or the `_burnAddress` if caller wishes to burn their tokens
     * @param value The amount of tokens to transfer, or to burn
     */
    function transfer(address to, uint256 value)
        public
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        returns (bool)
    {
        // If the recipient is the burn address then treat the transaction as a burn instead of a transfer
        if (super._isBurnAddress(to)) {
            // Ensure the account burning the tokens has been whitelisted
            require(super._isWhitelisted(msg.sender));

            // Handle additional burn logic and emit Burn event
            Burnable._burn(msg.sender, value);

            // Decrease token balance/total supply and emit Transfer event
            ERC20._burn(msg.sender, value);

            return true;
        } else {
            // Normal ERC20 transfer
            return super.transfer(to, value);
        }
    }

    /**
     * @dev Extension of the ERC20 approve function to enforce lifecycle behaviours.
     *
     * @notice Only use this function to set the spender allowance to zero.
     * To increment allowed value use the increaseAllowance function.
     * To decrement allowed value use the decreaseAllowance function.
     */
    function approve(address spender, uint256 value)
        public
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(spender)
        returns (bool)
    {
        return super.approve(spender, value);
    }

    /**
     * @dev Extension of the ERC20 approve function to enforce lifecycle behaviours.
     */
    function transferFrom(address from, address to, uint256 value)
        public
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(from)
        notBlacklisted(to)
        returns (bool)
    {
        // Do not allow transferFrom when the recipient is the burn address
        require(!super._isBurnAddress(to));

        return super.transferFrom(from, to, value);
    }

    /**
     * @dev Extension of the ERC20 increaseApproval function to enforce lifecycle behaviours.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(spender)
        returns (bool)
    {
        return super.increaseAllowance(spender, addedValue);
    }

    /**
     * @dev Extension of the ERC20 decreaseApproval function to enforce lifecycle behaviours.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(spender)
        returns (bool)
    {
        return super.decreaseAllowance(spender, subtractedValue);
    }


    /**
     * @dev Mints new tokens to the given `_to` account.
     * This function calls `Mintable._mint()` for minter limit logic, and emitting the Mint event.
     * This function calls `ERC20._mint()` for balance/total supply logic, and emitting the Transfer event.
     * Callable by an account with the minter role.
     *
     * @param to The account the tokens are being minted to
     * @param value The amount of tokens being minted
     * @param mintId A unique identifier for the mint transaction
     */
    function mint(address to, uint256 value, int256 mintId)
        external
        whenNotPaused
        onlyMinter
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        returns (bool)
    {
        // Decrease minter limit logic and emit Mint event
        Mintable._mint(msg.sender, to, value, mintId);

        // Increase token balance/total supply and emit Transfer event
        ERC20._mint(to, value);

        return true;
    }

    /**
     * @dev Transfer tokens from the given `from` account, if it's blacklisted, to the given `to` account.
     * This function calls `Blacklistable_transferFromBlacklisted` for emitting the TransferFromBlacklisted event.
     * This function calls `ERC20._transfer()` for transfer logic, and emitting the Transfer event.
     * Callable by an account with the owner role.
     *
     * @param from The account tokens are being transferred from, which must be blacklisted
     * @param to The account the tokens are being transferred to
     * @param value The amount of tokens being transferred
     */
    function transferFromBlacklisted(address from, address to, uint256 value)
        external
        whenNotPaused
        onlyOwner
        notBlacklisted(msg.sender)
        blacklisted(from)
        notBlacklisted(to)
        returns (bool)
    {
        // Emit TransferFromBlacklisted event
        Blacklistable._transferFromBlacklisted(msg.sender, from, to, value);

        // Execute the transfer and emit a Transfer event
        ERC20._transfer(from, to, value);

        return true;
    }
}