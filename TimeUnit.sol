// SPDX-License-Identifier: GPL-3.0 
pragma solidity >= 0.5.0 < 0.9.0; 
  
// https://www.geeksforgeeks.org/time-units-in-solidity/
contract TimeUnit { 
      
  // Declaring a  state variable that will  
  // store the current block timestamp 
  // as seconds since unix epoch(January 1, 1970) 
  uint256 private startTime; 
  
  // setting the startTime variable 
  function _setStartTime() internal { 
    startTime = block.timestamp; 
  } 
    
  // calculates numbers of seconds that  
  // have been elapsed since the startTime  
  // variable was set 
  function elapsedSeconds() public view returns (uint256) { 
    return (block.timestamp - startTime); 
  } 
    
  // calculates numbers of minutes that have been  
  // elapsed since the startTime variable was set 
  function elapsedMinutes() public view returns (uint256) { 
     
    // Both block.timestamp and startTime are in seconds  
    // Dividing them by 1 minutes == 60 seconds to find  
    // equivalent number of minutes 
    return (block.timestamp - startTime) / 1 minutes; 
  } 
}
