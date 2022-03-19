pragma solidity ^0.4.25;
import "./TokenErc20.sol";

contract HashedTimeLockERC20 {
    event HTLCERC20New(
        string indexed htlcId,
        address indexed sender,
        address indexed receiver,
        address tokenContract,
        uint256 amount,
        string hashlock,
        uint256 timelock
    );
    event HTLCERC20Withdraw(string indexed htlcId);
    event HTLCERC20Refund(string indexed htlcId);

    struct LockHTLCInfo {
        address sender;
        address receiver;
        address tokenContract;
        uint256 amount;
        string hashlock;
        uint256 timelock;
        bool withdrawn;
        bool refunded;
        string originalInfo;
    }

	//time需要大于当前区块时间  fisco bcos链时间戳精确到毫秒
    modifier futureTimelock(uint256 _time) {
        require(_time > (now/1000), "timelock time must be in the future");
        _;
    }
	//fisco bcos链时间戳精确到毫秒
    modifier HTLCExists(string _htlcId) {
        require(haveHTLCId(_htlcId), "_htlcId does not exist");
        _;
    }
 
    //fisco bcos链时间戳精确到毫秒
    modifier withdrawable(string _htlcId) {
        require(lockHTLCInfos[_htlcId].receiver == msg.sender, "withdrawable: not receiver");
        require(lockHTLCInfos[_htlcId].withdrawn == false, "withdrawable: already withdrawn");
        require(lockHTLCInfos[_htlcId].timelock > (now/1000), "withdrawable: timelock time must be in the future");
        _;
    }
    modifier refundable(string _htlcId) {
        require(lockHTLCInfos[_htlcId].sender == msg.sender, "refundable: not sender");
        require(lockHTLCInfos[_htlcId].refunded == false, "refundable: already refunded");
        require(lockHTLCInfos[_htlcId].withdrawn == false, "refundable: already withdrawn");
        require(lockHTLCInfos[_htlcId].timelock <= (now/1000), "refundable: timelock not yet passed");
        _;
    }

    mapping (string => LockHTLCInfo) lockHTLCInfos;

    /**
     * @dev 创建一个新的erc20 HTLC
  
     */
    function newERC20HTLC(
        address _receiver,
        string _hashlock,
        uint256 _timelock,
        address _tokenContract,
        uint256 _amount
    )
        external
        futureTimelock(_timelock)
        returns (bytes32 htlcId)
    {
		if(_amount <= 0)
			revert("token amount must be > 0");
		
		if(TokenErc20(_tokenContract).allowancesof(msg.sender, address(this)) < _amount)
			revert("token allowance must be >= amount");
		
        htlcId = keccak256(
                msg.sender,
                _receiver,
                _tokenContract,
                _amount,
                _hashlock,
                _timelock);

        // 哈希时间锁合约是否存在
		
		string memory hashID = bytes32ToString(htlcId);
        if (haveHTLCId(hashID))
            revert("Contract already exists");

        // 先转到合约账户进行锁定
        if (!TokenErc20(_tokenContract).transferFrom(msg.sender, address(this), _amount))
            revert("transferFrom sender to this failed");

        lockHTLCInfos[hashID] = LockHTLCInfo(
            msg.sender,
            _receiver,
            _tokenContract,
            _amount,
            _hashlock,
            _timelock,
            false,
            false,
            ""
        );

        emit HTLCERC20New(
            hashID,
            msg.sender,
            _receiver,
            _tokenContract,
            _amount,
            _hashlock,
            _timelock
        );
    }

	//资产提取者提供哈希锁的原文，解锁HTLC获得资产
    function withdraw(string _htlcId, string _originalInfo)
        external
        HTLCExists(_htlcId)
        withdrawable(_htlcId)
        returns (bool)
    {
	    bytes32 tmphash = keccak256(_originalInfo);
		
	    if(keccak256(bytes32ToString(tmphash)) != keccak256(lockHTLCInfos[_htlcId].hashlock))
			revert("hashlock hash does not match");

        LockHTLCInfo storage c = lockHTLCInfos[_htlcId];
        c.originalInfo = _originalInfo;
        c.withdrawn = true;
        TokenErc20(c.tokenContract).transfer(c.receiver, c.amount);
        emit HTLCERC20Withdraw(_htlcId);
        return true;
    }

    //交易超时，HTLC发起者撤销交易，资产回退至发起者账户
    function refund(string _htlcId)
        external
        HTLCExists(_htlcId)
        refundable(_htlcId)
        returns (bool)
    {
        LockHTLCInfo storage c = lockHTLCInfos[_htlcId];
        c.refunded = true;
        TokenErc20(c.tokenContract).transfer(c.sender, c.amount);
        emit HTLCERC20Refund(_htlcId);
        return true;
    }

	//只读方法，获得HTLC信息
    function getHTLCInfo(string _htlcId)
        public
        view
        returns (
            address sender,
            address receiver,
            address tokenContract,
            uint256 amount,
            string hashlock,
            uint256 timelock,
            bool withdrawn,
            bool refunded,
            string originalInfo
        )
    {
        if (haveHTLCId(_htlcId) == false)
            return (address(0), address(0), address(0), 0, "", 0, false, false, "");
        LockHTLCInfo storage c = lockHTLCInfos[_htlcId];
        return (
            c.sender,
            c.receiver,
            c.tokenContract,
            c.amount,
            c.hashlock,
            c.timelock,
            c.withdrawn,
            c.refunded,
            c.originalInfo
        );
    }

    //只读方法，判断htlcId是否已存在
    function haveHTLCId(string _htlcId) public
        view
        returns (bool exists)
    {
        exists = (lockHTLCInfos[_htlcId].sender != address(0));
    }

    //只读方法，计算哈希
    function hashX(string _x) 
        view
        returns (bytes32 exists)
    {
        return keccak256(_x);
    }
	
	
  // bytes32 转字符串
  function bytes32ToString(bytes32 x) pure public returns (string) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
		
        bytes memory bytesStringTrimmed = new bytes(charCount*2);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j*2] = byteToChar(bytesString[j] >> 4);
			bytesStringTrimmed[j*2+1] = byteToChar((bytesString[j] << 4) >> 4);
        }
        return string(bytesStringTrimmed);
    }
	//全部小写
	function byteToChar(byte x) pure public returns (byte) {
	    byte char = 0;
        if(x > 0x0f) 
		    revert();
		if(x >= 0x00 && x <= 0x09){
			char = byte(uint(x) + 0x30);
		}
		if(x >= 0x0a && x <= 0x0f){
			char = byte(uint(x) + 0x57);
		}
        return char;
    }
	
	// string类型转化为bytes32型转
    function stringToBytes32(string memory source) constant internal returns(bytes32 result){
        assembly{
            result := mload(add(source,32))
        }
    }
}

