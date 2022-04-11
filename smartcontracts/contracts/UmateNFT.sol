pragma solidity >=0.7.0 <0.9.0;
pragma abicoder v2;

contract UmateNFT {
    
    address public owner;
    uint256 feeCreateToken = 166666667;
    uint feeSell = 2;//fee in % for sale
    uint256 lastTokenId;
    uint maxCreatorFee = 100;
    
    struct Auction {
      uint256 startPrice;
      address highestBidder;
      uint256 highestBid;
      bool ended;
      // Продолжительность аукциона, сейчас + аукционEndTime = время окончания аукциона
      uint auctionEndTime;
    }

    struct UmateToken {
      string title;
      string desc;
      string url;
      string ownerName;
      string hash;
      uint256 price; //IN WEI
      bool allow_sell;
      uint countSells;
      address creator;
      uint creatorFee;
    }

    uint256 countTokens = 0;
    //tokens
    mapping(uint256 => UmateToken) tokens;
    //auctions
    mapping(uint256 => Auction) auctions;
    //auction exsit
    mapping(uint256 => bool) auctionExists;



    
    

    constructor() payable {
        owner = msg.sender;
    }
    


    //widthdraw tokens to owner address
   function withdraw(uint256 amount) public returns (uint status){
       if(msg.sender != owner){
           return 1;
       }
       else{
          payable(owner).transfer(amount);
          return 0;
       }
   }

   function createAuction(uint256 _tokenId, uint256 _startPrice, uint _biddingTime) public returns (uint status){
      uint res = 0;
      if(!tokenExists[_tokenId]){
        res = 1;
      }
      else if(tokenOwners[_tokenId] != msg.sender){
        res = 2;
      }
      //аукцион создан и есть ставка
      else if (auctionExists[_tokenId] && auctions[_tokenId].highestBid > 0){
        res = 3;
      }

      if(res == 0)
      {

            auctionExists[_tokenId] = true;

            Auction memory newAuction = Auction(
              _startPrice,
              msg.sender,
              0,
              false,
               block.timestamp + _biddingTime
            );
            auctions[_tokenId] = newAuction;
            auctions[_tokenId].ended = false;

      }

      return res;
   }


   //create new token auction
   function createAuctionToken(string memory _title, string memory _desc, string memory _url, string memory _ownerName, string memory _hash, uint256   _price, bool  _allow_sell, uint _creatorFee, uint256 _startPrice, uint _biddingTime) public payable returns ( uint256  newTokenId ){
    
       require(_creatorFee >= 0);
       require(_creatorFee <= maxCreatorFee);

        uint256 tokenId = 0;
        

        UmateToken memory newToken = UmateToken(
            _title,
            _desc,
            _url,
            _ownerName,
            _hash,
            _price,
            _allow_sell,
            0,
            msg.sender,
            _creatorFee
        );




        
        
        if(msg.value >= feeCreateToken){
            if(msg.value > feeCreateToken){
              payable(msg.sender).transfer(msg.value - feeCreateToken);   
            }

            tokens[countTokens] = newToken;
            countTokens ++;
            tokenId = countTokens;

            lastTokenId = tokenId;

            tokenOwners[tokenId] = msg.sender;
            tokenExists[tokenId] = true;
            countOwnerTokens[msg.sender]++;

            //create auction
            auctionExists[tokenId] = true;
            Auction memory newAuction = Auction(
              _startPrice,
              msg.sender,
              0,
              false,
               block.timestamp + _biddingTime
            );
            auctions[tokenId] = newAuction;
        }
        return tokenId;

   }


    function auctionEnd(uint256 _tokenId, bool _accept) public returns(uint status)
    {
      uint res = 0;
      if(!tokenExists[_tokenId]){
        res = 1;
      }
      else if(!auctionExists[_tokenId]){
        res = 2;
      }
      else if(auctions[_tokenId].ended){
        res = 3;
      }
      else if(tokenOwners[_tokenId] != msg.sender){
        res = 4;
      }
      if(res == 0){
        UmateToken memory token; 
        
        if(auctions[_tokenId].highestBid > 0){
          if(_accept){
            //update token price
            token = getToken(_tokenId);

            //Сумма продавцу за вычитом комиссии   системы

            uint256 owner_amount = auctions[_tokenId].highestBid - (auctions[_tokenId].highestBid * feeSell/100);



            //Если продавец не является создателем - делаем отчисление создателю
            if(token.creator != tokenOwners[_tokenId]){
                uint256 creator_amount = (auctions[_tokenId].highestBid * token.creatorFee)/100;
                //send money to creator
                payable(token.creator).transfer(creator_amount);

                owner_amount = owner_amount - creator_amount;
            }

            //send money to old owner
            payable(tokenOwners[_tokenId]).transfer(owner_amount);
            //update counters
            countOwnerTokens[tokenOwners[_tokenId]]--;
            countOwnerTokens[auctions[_tokenId].highestBidder]++;
            //set new owner
            tokenOwners[_tokenId] = auctions[_tokenId].highestBidder;
            tokens[_tokenId-1].countSells ++;
            tokens[_tokenId-1].allow_sell = false;



          }else{
              //auction cancel
              //return higestBid
              payable(auctions[_tokenId].highestBidder).transfer(auctions[_tokenId].highestBid);
          }
        
          auctions[_tokenId].highestBid = 0;
        }

        auctions[_tokenId].ended = true;
      }
      return res;
    }


    function getHighestBid(uint256 _tokenId) public returns(uint highestBid){
        require(
          auctionExists[_tokenId],
          "Auction not found"
        );

        require(
          tokenExists[_tokenId],
          "Token not found"
        );

        return auctions[_tokenId].highestBid;      
    }


    function getHighestBidder(uint256 _tokenId) public returns(address highestBidder){
        require(
          auctionExists[_tokenId],
          "Auction not found"
        );

        require(
          tokenExists[_tokenId],
          "Token not found"
        );

        return auctions[_tokenId].highestBidder;      
    }


    function bid(uint256 _tokenId) public payable returns(uint status){

        uint res = 0;

        if(!tokenExists[_tokenId]){
          res = 1;
        }
        else if(!auctionExists[_tokenId]){
          res = 2;
        }
        else if(auctions[_tokenId].ended){
          res = 3;
        }
        else if(msg.value < auctions[_tokenId].startPrice){
          res = 4;
        }
        else if(msg.value <= auctions[_tokenId].highestBid){
          res = 5;
        }
        else if(block.timestamp > auctions[_tokenId].auctionEndTime){
          res = 6;
        }

        //error  - money back
        if(res > 0){
          payable(msg.sender).transfer(msg.value);
        }
        else{
          if (auctions[_tokenId].highestBid != 0) {
            // Возврат предыдущей наивысшей ставки 
            payable(auctions[_tokenId].highestBidder).transfer(auctions[_tokenId].highestBid);   
          }
          auctions[_tokenId].highestBidder = msg.sender;
          auctions[_tokenId].highestBid = msg.value;
        }


        return res;
 
   }

   function createTokenTo(address _to, string memory _title, string memory _desc, string memory _url, string memory _ownerName, string memory _hash, uint256   _price, bool  _allow_sell, uint _creatorFee) public payable returns ( uint256  newTokenId ){
       require(_creatorFee >= 0);
       require(_creatorFee <= maxCreatorFee);

        uint256 tokenId = 0;
        UmateToken memory newToken = UmateToken(
            _title,
            _desc,
            _url,
            _ownerName,
            _hash,
            _price,
            _allow_sell,
            0,
            _to,
            _creatorFee
        );




        
        
        if(msg.value >= feeCreateToken){
            if(msg.value > feeCreateToken){
              payable(msg.sender).transfer(msg.value - feeCreateToken);   
            }

            tokens[countTokens] = newToken;
            countTokens ++;
            tokenId = countTokens;

            lastTokenId = tokenId;

            tokenOwners[tokenId] = _to;
            tokenExists[tokenId] = true;
            countOwnerTokens[_to]++;

        }                
        return tokenId;
   }


   function createToken(string memory _title, string memory _desc, string memory _url, string memory _ownerName, string memory _hash, uint256   _price, bool  _allow_sell, uint _creatorFee) public payable returns ( uint256  newTokenId ){
       require(_creatorFee >= 0);
       require(_creatorFee <= maxCreatorFee);

        uint256 tokenId = 0;
        UmateToken memory newToken = UmateToken(
            _title,
            _desc,
            _url,
            _ownerName,
            _hash,
            _price,
            _allow_sell,
            0,
            msg.sender,
            _creatorFee
        );




        
        
        if(msg.value >= feeCreateToken){
            if(msg.value > feeCreateToken){
              payable(msg.sender).transfer(msg.value - feeCreateToken);   
            }

            tokens[countTokens] = newToken;
            countTokens ++;
            tokenId = countTokens;

            lastTokenId = tokenId;

            tokenOwners[tokenId] = msg.sender;
            tokenExists[tokenId] = true;
            countOwnerTokens[msg.sender]++;

        }                
        return tokenId;
   }

    function testi(uint _i) public returns(uint i){
        return _i;
    }
    
    function testa() public returns(address a){
        return msg.sender;
    }


      


    function getTokensCounter() public view returns(uint256 counterTokens){
        return countTokens;
    }

    function getCountTokens() public view returns(uint256 ct){
        uint256 result = 0;

            uint256 tokenId;

            for (tokenId = 1; tokenId <= countTokens; tokenId++) {
                if (tokenExists[tokenId] == true)  {
                    result=result+1;
                }
            }

      return result;
    }

    function getCreateFee() public view returns(uint256 price){
        return feeCreateToken;
    }

    function setCreatePrice(uint256 _new_fee) public {
       require(msg.sender == owner);
      feeCreateToken = _new_fee;
    }
    
    function test_func() public returns(uint){
      return 333;
    }

   function removeToken(address _owner, uint256 _tokenId) private {
       tokenExists[_tokenId] = false;
       countOwnerTokens[_owner]--;

   }

    function tests(string memory _s) public returns(string memory s) {
        return _s;
    }

    function fallback() public payable {
    //    emit GotPaid(msg.value);
    }
/*
    function testCreate(string memory _url, uint   _price, bool  _allow_sell) public returns(uint256 tokenId) {
        uint256 tokenId = 0;
        UmateToken memory newToken = UmateToken(
            _url,
            _price,
            _allow_sell
        );
        
        //if(msg.value >= price_create_token){
            //payable(msg.sender).transfer(msg.value - price_create_token);   

            tokens.push(newToken);
            tokenId = tokens.length;
            lastTokenId = tokenId;

            tokenOwners[tokenId] = msg.sender;
            tokenExists[tokenId] = true;
            countOwnerTokens[msg.sender]++;

        //}                
        return tokenId;
    }
*/





   string constant private tokenName = "UmateNet NFT";
   string constant private tokenSymbol = "CFT";
   //uint256 constant private totalTokens = 1000000;
   //mapping(address => uint) private balances;
   mapping(uint256 => address) public tokenOwners;
   mapping(uint256 => bool) private tokenExists;
   mapping(address => mapping (address => uint256)) private allowed;
   mapping(address => uint) private countOwnerTokens;

   mapping(uint256 => string) tokenLinks;



    function getTokenPrice2(uint256 _tokenId) public returns(uint price){
      return lastTokenId;
    }



    function getTokenExist(uint256 _tokenId) public view returns(bool exist){
      return tokenExists[_tokenId];
    }

    function getTokenOwner(uint256 _tokenId) public view returns(address owner){
      return tokenOwners[_tokenId];
    }


    function buyToken2(uint256 _tokenId) public payable {
          require(tokenExists[_tokenId]);
            countOwnerTokens[tokenOwners[_tokenId]]--;
            countOwnerTokens[msg.sender]++;

            tokenOwners[_tokenId] = msg.sender;
    
    }


    function getTokenExists(uint256 _tokenId) public view returns (bool exist){
      return tokenExists[_tokenId];
    }

   function transfer(address _to, uint256 _tokenId) private {
       address currentOwner = msg.sender;
       address newOwner = _to;
       require(tokenExists[_tokenId]);
       require(currentOwner == ownerOf(_tokenId));
       require(currentOwner != newOwner);
       require(newOwner != address(0));
       //removeToken(_tokenId);
       tokenOwners[_tokenId] = newOwner;
       countOwnerTokens[currentOwner]--;
       countOwnerTokens[newOwner]++;
       //Transfer(currentOwner, newOwner, _tokenId);
   }


   function deleteAuction(uint256 _tokenId)  public returns (uint status){
      uint res = 0;

      if(!tokenExists[_tokenId]){
        res = 1;
      }
      else if(msg.sender != ownerOf(_tokenId)){
        res = 2;
      }
      //нельзя удалять если идет аукцион
      //аукцион создан и есть ставка
      else if (auctionExists[_tokenId] && auctions[_tokenId].highestBid > 0){
        res = 3;
      }
      if(res == 0){
       auctionExists[_tokenId] = false;        
      }
      return res;
    }

   function deleteToken(uint256 _tokenId) public returns (uint status){
      uint res = 0;

      if(!tokenExists[_tokenId]){
        res = 1;
      }
      else if(msg.sender != ownerOf(_tokenId)){
        res = 2;
      }
      //нельзя удалять если идет аукцион
      else if (auctionExists[_tokenId] && auctions[_tokenId].highestBid > 0){
        res = 3;
      }
      if(res == 0){
       countOwnerTokens[msg.sender]--;
       tokenExists[_tokenId] = false;
       auctionExists[_tokenId] = false;        
      }
      return res;
   }

    function buyToken(uint256 _tokenId) public payable returns(address tokenOwner){
      if(tokenExists[_tokenId] && tokenOwners[_tokenId] != msg.sender  )
      {
        UmateToken memory token; 
        token = getToken(_tokenId);
        if(msg.value >= token.price && token.allow_sell && !auctionExists[_tokenId]){
            //Сумма продавцу за вычитом комиссии   системы


            uint256 owner_amount = token.price - (token.price * feeSell/100);

            //Если продавец не является создателем - делаем отчисление создателю
            if(token.creator != tokenOwners[_tokenId]){
                uint256 creator_amount = (token.price * token.creatorFee)/100;
              //send money to creator
              payable(token.creator).transfer(creator_amount);

              owner_amount = owner_amount - creator_amount;
            }

            //send money to old owner
            payable(tokenOwners[_tokenId]).transfer(owner_amount);
            //update counters
            countOwnerTokens[tokenOwners[_tokenId]]--;
            countOwnerTokens[msg.sender]++;
            //set new owner
            tokenOwners[_tokenId] = msg.sender;
            tokens[_tokenId-1].countSells ++;
            //block selling after sell
            tokens[_tokenId-1].allow_sell = false;
            //money back
            //if(msg.value > token.price){
            //  payable(msg.sender).transfer(msg.value - token.price);   
            //}

        }else{
          //money back
          payable(msg.sender).transfer(msg.value);   
        }
      }else{
        //money back
        payable(msg.sender).transfer(msg.value);   
      }
      return tokenOwners[_tokenId];
    }



   function getTokensForSale(uint256 _start, uint _limit)  external view returns(uint256[] memory tokensList) 
   {
/*

        if((_start >= countTokens-1) && (_start <= countTokens)){
            uint256[] memory result = new uint256[](_limit);
            uint256 tokenId;
            uint256 resultIndex = 0;

            for (tokenId = _start + 1; tokenId <= _start + _limit + 1; tokenId++) {
                if ((tokenExists[tokenId] == true) ) {
                    result[resultIndex] = tokenId;
                    resultIndex++;
                }
            }
            return result;
        }else{
            return new uint256[](0);
        }*/
   }


   function getTokenIds(uint256 _start, uint _limit) external view returns(uint256[] memory tokenIds) 
   {
      uint256 count = getCountTokens();




        if((_start >= count-1) && (_start <= countTokens)){
            uint256[] memory result = new uint256[](_limit);
            uint256 tokenId;
            uint256 resultIndex = 0;

            for (tokenId = _start + 1; tokenId <= _start + _limit + 1; tokenId++) {
                if ((tokenExists[tokenId] == true) ) {
                    result[resultIndex] = tokenId;
                    resultIndex++;
                }
            }
            return result;
        }else{
            return new uint256[](0);
        }

   }


    function getTokenUrl(uint256 _tokenId) public returns (string memory url)
    {
      require(tokenExists[_tokenId]);
      UmateToken memory token; 

      token = getToken(_tokenId);

      string memory result;
      result = token.url;
      return result;
    }   

    function getTokenPrice(uint256 _tokenId) public  returns(uint256 price){
      require(tokenExists[_tokenId]);
      UmateToken memory token; 
      token = getToken(_tokenId);
      return token.price;
    }



    function tokensOfOwner(address _owner) external view returns(uint256[] memory ownerTokens) {
        uint tokenCount = countOwnerTokens[_owner];

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 resultIndex = 0;

            // We count on the fact that all cats have IDs starting at 1 and increasing
            // sequentially up to the totalCat count.
            uint256 tokenId;

            for (tokenId = 1; tokenId <= countTokens; tokenId++) {
                if ((tokenExists[tokenId] == true) && (tokenOwners[tokenId] == _owner)) {
                    result[resultIndex] = tokenId;
                    resultIndex++;
                }
            }

            return result;
        }
    }
    

   function name() public returns (string memory){
       return tokenName;
   }
   function symbol() public returns (string memory) {
       return tokenSymbol;
   }
   function ownerOf(uint256 _tokenId)  public returns (address){
       require(tokenExists[_tokenId]);
       return tokenOwners[_tokenId];
   }

   function transferFrom(address _from, address _to, uint256 _tokenId) external payable returns(bool status) {

      bool res = false;
       require(tokenExists[_tokenId]);
       address oldOwner = ownerOf(_tokenId);
       address newOwner = _to;
       //Текущий владелец = от кого передаем токен
       require(ownerOf(_tokenId) == _from);
       require(newOwner != oldOwner);
       //Делает запрос владелец или разрешенный управлющий
       require((msg.sender == oldOwner) || (allowed[oldOwner][msg.sender] == _tokenId));


       countOwnerTokens[tokenOwners[_tokenId]]--;

       tokenOwners[_tokenId] = newOwner;

       countOwnerTokens[tokenOwners[_tokenId]]++;

      res = true;

      return res;
   }

   function approve(address _to, uint256 _tokenId) public {
       require(msg.sender == ownerOf(_tokenId));
       require(msg.sender != _to);
       allowed[msg.sender][_to] = _tokenId;
       //Approval(msg.sender, _to, _tokenId);
   }




   function takeOwnership(uint256 _tokenId) private{
       require(tokenExists[_tokenId]);
       address oldOwner = ownerOf(_tokenId);
       address newOwner = msg.sender;
       require(newOwner != oldOwner);
       require(allowed[oldOwner][newOwner] == _tokenId);
       tokenOwners[_tokenId] = newOwner;
       //Transfer(oldOwner, newOwner, _tokenId);
   }

   function getCountOwnerTokens(address _owner) public view returns (uint countTokens){
      return countOwnerTokens[_owner];
   }

   function updateTokenAllowSell(uint256 _tokenId, bool _allow_sell) public{
      require(tokenExists[_tokenId]);
      require(tokenOwners[_tokenId] == msg.sender);
      tokens[_tokenId-1].allow_sell = _allow_sell;      
   }

   function updateTokenPrice(uint256 _tokenId, uint256 _price) public{
      require(tokenExists[_tokenId]);
      require(tokenOwners[_tokenId] == msg.sender);
      tokens[_tokenId-1].price = _price;      
   }

   function updateToken(uint256 _tokenId, string memory _title, string memory _desc, string memory _ownerName, uint256   _price, bool  _allow_sell) public{
      require(tokenExists[_tokenId]);
      require(tokenOwners[_tokenId] == msg.sender);
      tokens[_tokenId-1].price = _price;
      tokens[_tokenId-1].allow_sell = _allow_sell;
      tokens[_tokenId-1].title = _title;
      tokens[_tokenId-1].desc = _desc;
      tokens[_tokenId-1].ownerName = _ownerName;
   }



   function getToken(uint256 _tokenId) public returns (UmateToken memory token){
       require(tokenExists[_tokenId]);
       return tokens[_tokenId-1];
   }
}