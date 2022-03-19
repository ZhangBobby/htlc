pragma solidity ^0.4.25;
import "./TokenErc721.sol";

contract test {

    event e1(string hash, bytes32 b);
	event e2(bytes32 hash);
	string hashlock;
   

	//资产提取者提供哈希锁的原文，解锁HTLC获得资产
    function withdraw(string _originalInfo)
        external
        returns (bool)
    {
		bytes32 tmphash = keccak256(_originalInfo);
	    if(keccak256(hashlock) != keccak256(bytes32ToString(tmphash)))
		{
			e1(hashlock, tmphash);
		}else{
			e2(tmphash);		
		}


        
        return true;
    }
	

    

	//只读方法，计算哈希
    function hashX(string _x)
        public
    {
        hashlock = bytes32ToString(keccak256(_x));
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

