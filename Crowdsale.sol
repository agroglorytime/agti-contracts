// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Crowdsale is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant PERIOD_CHANGER_ROLE = keccak256("PERIOD_CHANGER_ROLE");

    IERC20 public immutable AGTI;

    uint256 public currentVestingPeriod;

    uint256 private totalBought;

    mapping(address => uint256) public price;
    mapping(uint256 => mapping(address => uint256)) public bought;

    event AddBought(address indexed user, uint256 indexed period, uint256 amount, uint256 timestamp);
    event ClaimBought(address indexed user, uint256[] period);

    constructor(IERC20 _agti, address owner, address periodChanger) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(PERIOD_CHANGER_ROLE, owner);
        _setupRole(PERIOD_CHANGER_ROLE, periodChanger);
        AGTI = _agti;
    }

    function getAmounts(uint256[] calldata period, address user) external view returns(uint256[] memory) {
        uint256[] memory amounts = new uint256[](period.length);
        for (uint256 i; i < period.length; i++) {
            amounts[i] = bought[period[i]][user];
        }
        return amounts;
    }

    function setPrice(address token, uint256 _price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        price[token] = _price;
    }

    function getToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            payable(_msgSender()).transfer(address(this).balance);
        }
        else if (token == address(AGTI)) {
            AGTI.transfer(_msgSender(), avaliableToBuy());
        }
        else {
            IERC20(token).transfer(_msgSender(), IERC20(token).balanceOf(address(this)));
        }
    }

    function gift(address account, uint256 amount, uint256 timestamp) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount > 0 && amount <= avaliableToBuy(), "Too low or too high amount to gift");
        totalBought += amount;
        bought[currentVestingPeriod][account] += amount;
        if (timestamp == 0 || currentVestingPeriod > 0) {
            emit AddBought(account, currentVestingPeriod, amount, block.timestamp);
        }
        else {
            emit AddBought(account, currentVestingPeriod, amount, timestamp);
        }
    }

    function startNewVestingPeriod() external onlyRole(PERIOD_CHANGER_ROLE) {
        currentVestingPeriod++;
    }

    function buy(address tokenToPay, uint256 amountToGet) external payable nonReentrant {
        require(amountToGet > 0 && amountToGet <= avaliableToBuy(), "Too low or too high amount to get");
        require(price[tokenToPay] > 0, "Cannot buy with specified token");
        if (tokenToPay == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            require(msg.value == amountToGet * price[tokenToPay], "Wrong amount of native currency sent");
        }
        else {
            require(msg.value == 0, "Cannot send native currency while paying with token");
            IERC20(tokenToPay).safeTransferFrom(_msgSender(), address(this), amountToGet * price[tokenToPay]);
        }
        bought[currentVestingPeriod][_msgSender()] += amountToGet;
        totalBought += amountToGet;
        emit AddBought(_msgSender(), currentVestingPeriod, amountToGet, block.timestamp);
    }

    function claim(uint256[] calldata period) external nonReentrant {
        uint256 sum;
        for (uint256 i; i < period.length; i++) {
            require(period[i] < currentVestingPeriod, "Not avaliable for this period yet");
            sum += bought[period[i]][_msgSender()];
            delete bought[period[i]][_msgSender()];
        }
        AGTI.transfer(_msgSender(), sum);
        totalBought -= sum;
        emit ClaimBought(_msgSender(), period);
    }

    function avaliableToBuy() public view returns(uint256) {
        return AGTI.balanceOf(address(this)) - totalBought;
    }
}