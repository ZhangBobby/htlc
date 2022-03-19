pragma solidity ^0.4.18;

contract TokenErc20 {

    string public name;
    string public symbol;
    uint8 decimals;
    uint public totalSupply;

	event Transfer(address indexed _from, address indexed _to, uint _value);//transfer方法调用时的通知事件
	event Approval(address indexed _owner, address indexed _spender, uint _value); //approve方法调用时的通知事件
    
    mapping(address=>uint) public balances;
    mapping(address => mapping(address => uint)) allowances;
    uint256 constant private MAX_UINT256 = 2**256 - 1;
    function TokenErc20(
        string _name, 
        string _symbol,
        uint8 _decimals,
        uint _initialSupply
        ) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        balances[msg.sender] = _initialSupply;
    }
    
	//获取总的发行量
	function totalSupply() constant public returns (uint ){
		return totalSupply;
	}

	//查询账户余额
    function balanceOf(address _owner) public view returns(uint balance) {
        return balances[_owner];    
    }
    // 发送Token到某个地址(转账)
    function transfer(address _to, uint _value) public returns(bool success) {
         success = false;
		require(balances[msg.sender] >= _value);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
		success = true;
    }
    //从地址from 发送token到to地址
    function transferFrom(address _from, address _to, uint _value) public returns(bool success){
	    success = false;
        require(balances[_from] >= _value);
        require(allowances[_from][_to] >= _value);
        balances[_from] -= _value;
        balances[_to] += _value;
		if (allowances[_from][msg.sender] < MAX_UINT256) {
            allowances[_from][msg.sender] -= _value;
        }
        emit Transfer(_from, _to, _value);
		success = true;
    }
    //允许_spender从你的账户转出token
    function approve(address _spender, uint _value) public {
        allowances[msg.sender][_spender] = _value;   
    }
    //查询允许spender转移的Token数量
    function allowancesof(address _owner, address _spender) public view returns(uint allowance) {
        return allowances[_owner][_spender];    
    }
}