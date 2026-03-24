const express = require("express");
const app = express();

app.get("/health",(req,res)=>{
  res.json({status:"ok"});
});

app.get("/ready",(req,res)=>{
  res.json({status:"ready"});
});

app.listen(3000,()=>{
  console.log("billing service running");
});
