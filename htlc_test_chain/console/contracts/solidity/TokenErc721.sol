pragma solidity ^0.4.18;


contract SafeMath {
    uint256 constant public MAX_UINT256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    function safeAdd(uint256 x, uint256 y) pure public  returns (uint256 z) {
        if (x > MAX_UINT256 - y) revert();
        return x + y;
    }

    function safeSub(uint256 x, uint256 y) pure public returns (uint256 z) {
        if (x < y) revert();
        return x - y;
    }

    function safeMul(uint256 x, uint256 y) pure public returns (uint256 z) {
        if (y == 0) return 0;
        if (x > MAX_UINT256 / y) revert();
        return x * y;
    }
}


contract TokenErc721 is SafeMath{

   // Events，分别用来记录和授权
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);


  // token ID 到 持有人owner的映射
  mapping (uint256 => address)  tokenOwner;

  // token ID 到授权地址address的映射
  mapping (uint256 => address)  tokenApprovals;

  // 持有人到持有的token数量的映射
  mapping (address => uint256)  ownedTokensCount;

  // 持有人到操作人授权的映射
  mapping (address => mapping (address => bool))  operatorApprovals;

  /**
   * @dev 确保msg.sender是tokenId的持有人
   */
  modifier onlyOwnerOf(uint256 _tokenId) {
    require(ownerOf(_tokenId) == msg.sender);
    _;
  }

  /**
   * @dev 通过检查msg.sender是否是代币的持有人，被授权或者操作人来确保msg.sender可以交易一个token

   */
  modifier canTransfer(uint256 _tokenId) {
    require(isApprovedOrOwner(msg.sender, _tokenId));
    _;
  }

  /**
   * @dev 获取持有者的代币总数

   */
  function balanceOf(address _owner) public view returns (uint256) {
    require(_owner != address(0));
    return ownedTokensCount[_owner];
  }

  /**
   * @dev 根据token ID获取持有者
   */
  function ownerOf(uint256 _tokenId) public view returns (address) {
    address owner = tokenOwner[_tokenId];
    require(owner != address(0));
    return owner;
  }

  /**
   * @dev 指定的token是否存在
   */
  function exists(uint256 _tokenId) public view returns (bool) {
    address owner = tokenOwner[_tokenId];
    return owner != address(0);
  }

  /**
   * @dev 获取token被授权的地址，如果没有设置地址则为0
   */
  function getApproved(uint256 _tokenId) public view returns (address) {
    return tokenApprovals[_tokenId];
  }
  
   /**
   * @dev 返回给定的spender是否可以交易一个给定的token
   */
  function isApprovedOrOwner(address _spender, uint256 _tokenId)  view returns (bool) {
    address owner = ownerOf(_tokenId);
    return (
      _spender == owner ||
      getApproved(_tokenId) == _spender ||
      isApprovedForAll(owner, _spender)
    );
  }
  
    /**
   * @dev 查询是否操作人被指定的持有者授权
   */
  function isApprovedForAll( address _owner, address _operator) public view returns (bool)
  {
    return operatorApprovals[_owner][_operator];
  }

 /**
   * @dev 批准另一个人address来交易指定的代币
   * @dev 0 address 表示没有授权的地址
   * @dev 给定的时间内，一个token只能有一个批准的地址
   */
  function approve(address _to, uint256 _tokenId) public {
    address owner = ownerOf(_tokenId);
    require(_to != owner);
    require(msg.sender == owner || isApprovedForAll(owner, msg.sender));

    if (getApproved(_tokenId) != address(0) || _to != address(0)) {
      tokenApprovals[_tokenId] = _to;
      emit Approval(owner, _to, _tokenId);
    }
  }
  
    /**
   * @dev 设置或者取消对操作人的授权
   * @dev 一个操作人可以代表他们转让发送者的所有token
   */
  function setApprovalForAll(address _to, bool _approved) public  {
    require(_to != msg.sender);
    operatorApprovals[msg.sender][_to] = _approved;
    emit ApprovalForAll(msg.sender, _to, _approved);
  }

  /**
   * @dev 将指定的token所有权转移给另外一个地址
   * @dev 不鼓励使用这个方法，尽量使用`safeTransferFrom` 
   * @dev 要求 msg.sender 必须为所有者，已授权或者操作人
  */
  function transferFrom(address _from,address _to, uint256 _tokenId)  public  canTransfer(_tokenId) returns(bool success)
  {
    success = false;
    require(_from != address(0));
    require(_to != address(0));

    clearApproval(_from, _tokenId);
    removeTokenFrom(_from, _tokenId);
    addTokenTo(_to, _tokenId);
	success = true;
    emit Transfer(_from, _to, _tokenId);
  } 

  /**
   * @dev 增发一个新token的内部方法
   * @dev 如果增发的token已经存在则撤销
   */
  function _mint(address _to, uint256 _tokenId) public {
    require(_to != address(0));
    addTokenTo(_to, _tokenId);
    emit Transfer(address(0), _to, _tokenId);
  }

  /**
   * @dev 销毁一个token的内部方法
   * @dev 如果token不存在则撤销
   */
  function _burn(address _owner, uint256 _tokenId) public {
    clearApproval(_owner, _tokenId);
    removeTokenFrom(_owner, _tokenId);
    emit Transfer(_owner, address(0), _tokenId);
  }

  /**
   * @dev 清除当前的给定token的授权，内部方法
   * @dev 如果给定地址不是token的持有者则撤销
   */
  function clearApproval(address _owner, uint256 _tokenId) public  {
    require(ownerOf(_tokenId) == _owner);
    if (tokenApprovals[_tokenId] != address(0)) {
      tokenApprovals[_tokenId] = address(0);
      emit Approval(_owner, address(0), _tokenId);
    }
  }

  /**
   * @dev 内部方法，将给定的token添加到给定地址列表中
   * @param _to address 指定token的新所有者
   */
  function addTokenTo(address _to, uint256 _tokenId) public {
    tokenOwner[_tokenId] = _to;
    ownedTokensCount[_to] = safeAdd(ownedTokensCount[_to],1);
  }

  /**
   * @dev 内部方法，将给定的token从地址列表中移除
   * @param _from address 给定token的之前持有中地址
   */
  function removeTokenFrom(address _from, uint256 _tokenId)  {
    require(ownerOf(_tokenId) == _from);
    ownedTokensCount[_from] = safeSub(ownedTokensCount[_from],1);
    tokenOwner[_tokenId] = address(0);
  }

  
}

