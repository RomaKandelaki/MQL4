//+------------------------------------------------------------------+
//|                                                 mGRID EA_V10.mq4 |
//|                                                   version 10X_v6 |
//|                                                     by           |
//|                                                     date 2015/10 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "X"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//---- input parameters ---------------------------------------------+

extern bool                SLOWKILLSWITCH          =false;
extern bool                EMERGENCYSTOP_Hedge     =false;
extern bool                EMERGENCYSTOP_Close     =false;

extern double              LOTS                    =0.25;
extern double              SELLLotsFactor          =10;
extern double              BUYLotsFactor           =10;
extern double              v6_MAXLOTSIZE           =10;
extern double              v4_BUYMAXLOTSIZE        =10;
extern double              v4_SELLMAXLOTSIZE       =10;
extern bool                EnableDynamicLots       =true;
extern bool                EnableDynamicLotsFactor =true;
extern double              DynamicEquityUSD        =1000;
extern double              DynamicEquityLots       =0.1;

extern double              STOPLOSS                =2500;
extern int                 INCREMENT               =20;
extern int                 RETRACEMENT             =200;
extern int                 RANGE                   =200;
extern int                 CloseAtProfit           =50;

extern double              v4_order_freq           =0.5;
extern double              v4_buygridspace_factor  =1;
extern double              v4_sellgridspace_factor =1;

extern ENUM_TIMEFRAMES     TIMEFRAME               =PERIOD_M1;
extern bool                EnableFridayClose       =false;
extern int                 FridayCloseTime         =16;
extern int                 FridayLoopCloseTime     =18;

extern int                 MAGIC                   =1803;
extern bool                EnableRetracement       =true;
extern bool                EnableBolinAndWpr       =false;


extern int                 MovingPeriod             = 1440;
extern double              compensationProfitUSD    = 300;
extern int                 ma_offset                = 200;


extern double              compensationMAXLOTSIZE_per_Position  = 38;
extern double              compensationUNITLOTSIZE_per_Position = 20;
extern double              StrongTrendTPBuffer                  = 500;
extern double              compensationLowerLimitUSD            = 100;


//|.......................................................................................|
//|......................................  Variables .....................................|
//|.......................................................................................|  

bool          key=true;
bool          GridDisabled=false;

int           EquityOnMonday;
int           EquityOnFriday;
bool          Enter=true;

int           Tally,LOrds,send,
SOrds,PendBuy,PendSell;
int           Spread;
int           StopLevel;
int           ticket;

double        initialLots;
double        initialEquity;

double        maxLots=0;
double        dynamicFactor;

double        lastAskPrice;
double        lastBidPrice;

bool          setup= false;
bool          exit = false;
bool          exitFriday=false;

double        UpperLimit              =1.14;  /*// In pips*/
double        LowerLimit              =1.08;

int           LEVELS=300;

double        requiredLots=300*0.01;

int           TSwap;

double        high,low,difference;

double        old_dynamic_equity_lotsize;

datetime      lastTradeTime=0;

#define       THIS_BAR 0


double         HAOpen3;
double         HAClose3;

double         HAOpen4;
double         HAClose4;

int            Current=0;

double        MA_crossPrice;

bool          trig1 = true;
bool          trig2 = false;
bool          trig3 = true;
bool          trig4 = false;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*
|---------------------------------------------------------------------------------------|
|-----------------------------------   Initialization   --------------------------------|
|---------------------------------------------------------------------------------------| 
*/

int init()
  {
//+------------------------------------------------------------------+ 

// Comment(wpr+" "+BolingerLowerBand);
   initialLots=LOTS;
   initialEquity=AccountEquity();

   old_dynamic_equity_lotsize=LOTS;

//+------------------------------------------------------------------+
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+

int deinit()
  {
   return(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*
|---------------------------------------------------------------------------------------|
|=====================================EA Start Function=================================|
|---------------------------------------------------------------------------------------|
*/

int start()
  {

   DynamicLots();

   if(DayOfWeek()==MONDAY && TimeHour(TimeGMT())==1)
     {
      EquityOnMonday=AccountEquity();
      exitFriday=false;

     }

   if(exit || exitFriday)return 0;



   if(Bid>UpperLimit || Bid<LowerLimit)
     {

      CloseGrid();
      setup=false;
     }

// do not work on holidays.
   if(EnableFridayClose)
     {

      if(DayOfWeek()==FRIDAY && TimeHour(TimeGMT())>FridayCloseTime && AccountEquity()>=AccountBalance())
        {

         while(OrdersTotal()!=0)
           {

            EndSession();

           }

         exitFriday=true;
         return 0;

        }

     }

   if(!setup)
     {

      UpperLimit = Bid+RANGE*Point;
      LowerLimit = Bid-RANGE*Point;
      LEVELS=(UpperLimit-LowerLimit)/Point/INCREMENT;
      requiredLots=LEVELS*LOTS;
      maxLots=Lot(requiredLots);
      setup=true;

     }

/*   if(maxLots<requiredLots)
     {

      Comment("not enough money try lotsize of: ",maxLots/(LEVELS*2));
      return 0;
     }
     
     
     */

   if(OrdersTotal()<1 && check_sell_condition())
     {

      Sell();

     }

   if(OrdersTotal()<1 && check_buy_condition())
     {

      Buy();

     }

   check_close_condition();

   if(EMERGENCYSTOP_Close)
     {

      while(OrdersTotal()!=0)
        {

         EndSession();

        }

      exit=true;
      return 0;

     }

   if(EMERGENCYSTOP_Hedge)
     {

      while(PendBuy>0 || PendSell>0)
        {
         CloseGrid();
         CloseAllPending();
         PrintStats();
        }

      double newLot=SOrds*LOTS;
      int ticket=OrderSend(Symbol(),OP_BUY,newLot,Ask,3,0,0,"Hedge",16384,0,clrAqua);
      if(ticket<0)
        {
         ticket=OrderSend(Symbol(),OP_BUY,newLot,Ask,3,0,0,"Hedge",16384,0,clrAqua);
         Print("OrderSend failed with error #",GetLastError());
        }
      else
         Print("OrderSend placed successfully");

      newLot=LOrds*LOTS;
      ticket=OrderSend(Symbol(),OP_SELL,newLot,Bid,3,0,0,"Hedge",16384,0,clrYellow);
      if(ticket<0)
        {
         ticket=OrderSend(Symbol(),OP_SELL,newLot,Bid,3,0,0,"Hedge",16384,0,clrYellow);
         Print("OrderSend failed with error #",GetLastError());
        }
      else
         Print("OrderSend placed successfully");

      exit=true;
      return 0;

     }

/*
|---------------------------------------------------------------------------------------|
|---------------------------------- Begin Placing Orders -------------------------------|
|---------------------------------------------------------------------------------------|
*/

   int cpt,profit,total,ticket=0;
   double spread=(Ask-Bid)/Point,InitialPrice=0;
//----

   if(INCREMENT<MarketInfo(Symbol(),MODE_STOPLEVEL)+spread) INCREMENT=1+MarketInfo(Symbol(),MODE_STOPLEVEL)+spread;

   PrintStats();

//+------------------------------------------------------------------+   

   Comment(
           Space(),
           "mGRID EXPERT ADVISOR ver 2.0",Space(),
           "FX Acc Server:",AccountServer(),Space(),
           "Date: ",Month(),"-",Day(),"-",Year()," Server Time: ",Hour(),":",Minute(),":",Seconds(),Space(),
           "Minimum Lot Sizing: ",MarketInfo(Symbol(),MODE_MINLOT),Space(),
           "Account Balance:  $",AccountBalance(),Space(),
           "FreeMargin: $",AccountFreeMargin(),Space(),
           "Total Orders Open: ",OrdersTotal(),Space(),
           "Day Open Price:  ",NormalizeDouble(day_open_price(),4),Space(),
           "Pip Spread:  ",MarketInfo(Symbol(),MODE_SPREAD),Space(),
           "Leverage: ",AccountLeverage(),Space(),
           "Effective Leverage: ",AccountMargin()*AccountLeverage()/AccountEquity(),Space(),
           "Increment="+INCREMENT,Space(),
           "Lots:  ",LOTS,Space(),
           "Levels: "+LEVELS,Space(),
           "Float: ",Tally," Longs: ",LOrds," Shorts: ",SOrds,Space(),
           "SellStops: ",PendSell," BuyStops: ",PendBuy," TotalSwap: ",TSwap);

   return(0);



  }
//+------------------------------------------------------------------+
//| End of start function                                            |
//+------------------------------------------------------------------+


/*
|---------------------------------------------------------------------------------------|
|----------------------------------   Custom functions   -------------------------------|
|---------------------------------------------------------------------------------------|
*/

//===================================== MA_Indicator ==================================//

/** 
 * 
 * Calculates the Moving Average indicator and returns its value.
 *
 * @return    Numerical value of the Moving Average indicator
 */

double MA_indicator()
  {

   double ma=iMA(
                 NULL,             // symbol
                 TIMEFRAME,        // timeframe
                 MovingPeriod,     // MA averaging period
                 0,                // MA shift
                 MODE_SMA,         // averaging method
                 PRICE_CLOSE,      // applied price
                 0                 // shift
                 );

   return ma;

  }
//===================================== MA_Indicator_Upper_Band ==================================//

/** 
 * 
 * Calculates the Moving Average indicator upper band and returns its value.
 *
 * @param   points    the value in points above the Moving Avarage.
 * @return            Numerical value of the Moving Average indicator upper band.
 */

double MA_UpperBand(int points)
  {

   double ma_upper=MA_indicator()+points*Point;
   return ma_upper;

  }
//===================================== MA_Indicator_Upper_Band ==================================//

/** 
 * 
 * Calculates the Moving Average indicator lower band and returns its value.
 *
 * @param   points    the value in points below the Moving Avarage.
 * @return            Numerical value of the Moving Average indicator lower band.
 */

double MA_LowerBand(int points)
  {

   double ma_lower=MA_indicator()-points*Point;
   return ma_lower;

  }
//===================================== Daily Open ==================================//

/** 
 * 
 * Calculates the day open price.
 *
 * @return     Numerical value of the open price of the current daily bar.
 */

double day_open_price()
  {

   double dayOpenPrice=iOpen(
                             NULL,          // symbol
                             PERIOD_D1,     // timeframe
                             0              // shift
                             );
   return dayOpenPrice;

  }
//===================================== Sell Logic ==================================// 

/** 
 * 
 * Checks whether a sell condition exists.
 * For a sell condition to exist
 * the ma value and the bid price has to be below the daily open price
 * and the current price has to retrace back to the ma upper band.
 * @return     <code>true</code> if there exists a sell condition.
 */
bool check_sell_condition()
  {

   bool condition=false;

   if(MA_indicator()<day_open_price() && Bid<day_open_price() && Bid>MA_UpperBand(ma_offset))
      condition=true;

   return condition;


  }
//===================================== Buy Logic ==================================// 

/** 
 * 
 * Checks whether a buy condition exists.
 * For a buy condition to exist
 * the ma value and the ask price has to be above the daily open price
 * and the current price has to retrace back to the ma lower band.
 * @return     <code>true</code> if there exists a buy condition.
 */
bool check_buy_condition()
  {

   bool condition=false;

   if(MA_indicator()>day_open_price() && Ask>day_open_price() && Ask<MA_LowerBand(ma_offset))
      condition=true;

   return condition;


  }
//===================================== Sell Order ==================================//

/** 
 * 
 * sends a sell order to the server.
 * and prints an error message 
 * if the order fails to open.
 * 
 */
void Sell()
  {

   int ticket=OrderSend(Symbol(),OP_SELL,LOTS,Bid,2,0,0,0,MAGIC,0);

   if(ticket>0)
     {
      lastTradeTime=Time[THIS_BAR];
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) Print("Sell order opened : ",OrderOpenPrice());
     }
   else Print("Error opening Sell order : ",GetLastError());

  }
//===================================== Buy Order ==================================//

/** 
 * 
 * sends a buy order to the server.
 * and prints an error message 
 * if the order fails to open.
 * 
 */
void Buy()
  {

   ticket=OrderSend(Symbol(),OP_BUY,LOTS,Ask,2,0,0,0,MAGIC,0);

   if(ticket>0)
     {
      lastTradeTime=Time[THIS_BAR];
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) Print("Buy order opened : ",OrderOpenPrice());
     }
   else Print("Error opening Buy order : ",GetLastError());

  }
//===================================== Close Orders Logic ==================================//

/** 
 * 
 * checks whether a close condition exists for current open order.
 * closes the orders if the current ask or bid price reaches the ma price
 * and there is a positive balance.
 */
bool check_close_condition()
  {
   bool close=false;
   double ma=MA_indicator();
   if(AccountEquity()>AccountBalance() && (Bid>ma || Ask<ma))
      close=true;

   return close;



  }
//===================================== CHECK PROFIT ==================================//

double checkProfit()
  {

   double profit=0.01;

   for(int cnt=0;cnt<OrdersTotal();cnt++)

     {

      OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
      if(OrderType()==OP_BUY)
        {

         profit+=(iMA(NULL,0,MovingPeriod,0,MODE_SMA,PRICE_CLOSE,0)
                  -OrderOpenPrice())*OrderLots()*MarketInfo(Symbol(),MODE_LOTSIZE);

        }

     }

   for(int cnt=0;cnt<OrdersTotal();cnt++)

     {

      OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
      if(OrderType()==OP_SELL)
        {

         profit+=(-1*(iMA(NULL,0,MovingPeriod,0,MODE_SMA,PRICE_CLOSE,0)
                  -OrderOpenPrice())*OrderLots()*MarketInfo(Symbol(),MODE_LOTSIZE));

        }

     }

   return profit;

  }
//============ LOTS ADDED FUNCTION: EXTREME MEASURE TO DETERMINE LOTS TO BE ADDED TO COMPENSATE FOR MISSING TP AT MA HIT ======================//
//------------------------------------------ WE GUARANTEE PROFIT AT MA HIT WITH THIS EXTREME LOGIC -----------------------------

double LotsAdded()
  {

   double lotsCompensation;

   double profit=1;

   for(int cnt=0;cnt<OrdersTotal();cnt++)
     {

      OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);

      if(OrderType()==OP_SELL)
        {
         profit=Bid-iMA(NULL,0,MovingPeriod,0,MODE_SMA,PRICE_CLOSE,0);
        }

      if(OrderType()==OP_BUY)
        {
         profit=iMA(NULL,0,MovingPeriod,0,MODE_SMA,PRICE_CLOSE,0)-Ask;
        }
     }

   lotsCompensation=((-1*Tally)+compensationProfitUSD)/(profit*MarketInfo(Symbol(),MODE_LOTSIZE));

   return lotsCompensation;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*
|---------------------------------------------------------------------------------------|
|----------------------------------   MA Crossing   -------------------------------|
|---------------------------------------------------------------------------------------|
*/

void MA_Crossing()
  {

   double ma;

//--- go trading only for first ticks of new bar
   if(Volume[0]>1)
     {
      //--- get Moving Average 
      ma=iMA(NULL,0,MovingPeriod,0,MODE_SMA,PRICE_CLOSE,0);
      //--- get Moving Average Cross Price
      if(Open[1]>ma && Close[1]<ma)
        {
         MA_crossPrice=ma;
        }
      //--- get Moving Average Cross Price
      if(Open[1]<ma && Close[1]>ma)
        {
         MA_crossPrice=ma;
        }
      //---
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*
|---------------------------------------------------------------------------------------|
|----------------------------------   Custom functions   -------------------------------|
|---------------------------------------------------------------------------------------|
*/

int Retracement()
  {

   double Initial=Ask;

   lastAskPrice = Ask;
   lastBidPrice = Bid;

   if(EnableDynamicLotsFactor && LOTS*SELLLotsFactor>v4_SELLMAXLOTSIZE){SELLLotsFactor=SELLLotsFactor/2;Print("RECTIFIED LotsFactor : ",SELLLotsFactor);}
   if(EnableDynamicLotsFactor  &&  LOTS*BUYLotsFactor>v4_BUYMAXLOTSIZE){BUYLotsFactor=BUYLotsFactor/2;Print("RECTIFIED LotsFactor : ",BUYLotsFactor);}

   for(int cpt=1;cpt<=2;cpt++)
     {

      ticket=OrderSend(Symbol(),OP_SELLSTOP,LOTS*SELLLotsFactor,Initial-cpt*INCREMENT*v4_sellgridspace_factor*Point,2,0,0,"comment",1000,0);
      if(ticket>0)
        {
         lastTradeTime=Time[THIS_BAR];
         if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) Print("SELLSTOP order opened : ",OrderOpenPrice());
        }
      else Print("Error opening SELLSTOP order : ",GetLastError());

      ticket=OrderSend(Symbol(),OP_BUYSTOP,LOTS*BUYLotsFactor,Initial+cpt*INCREMENT*v4_buygridspace_factor*Point,2,0,0,"comment",1000,0);
      if(ticket>0)
        {
         lastTradeTime=Time[THIS_BAR];
         if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) Print("BUYSTOP order opened : ",OrderOpenPrice());
        }
      else Print("Error opening BUYSTOP order : ",GetLastError());

     }

   return 0;
  }
//========== FUNCTION LotCalculation

double Lot(double dLots) // User-defined function
  {

   double Lots_New;
   string Symb=Symbol();                    // Symbol
   double One_Lot=MarketInfo(Symb,MODE_MARGINREQUIRED);//!-lot cost
   double Min_Lot=MarketInfo(Symb,MODE_MINLOT);// Min. amount of lots
   double Step=MarketInfo(Symb,MODE_LOTSTEP);//Step in volume changing
   double Free=AccountFreeMargin()*0.9;         // Free margin
//----------------------------------------------------------------------------- 3 --
   if(dLots>0)                                 // Volume is explicitly set..
     {                                         // ..check it
      double Money=dLots*One_Lot;               // Order cost
      if(Money<=AccountFreeMargin()*0.9) // Free margin covers it..
         Lots_New=dLots;                        // ..accept the set one
      else                                     // If free margin is not enough..
      Lots_New=MathFloor(Free/One_Lot/Step)*Step;// Calculate lots
     }
//----------------------------------------------------------------------------- 4 --

//----------------------------------------------------------------------------- 5 --
   if(Lots_New<Min_Lot) // If it is less than allowed..
      Lots_New=Min_Lot;                        // .. then minimum

   return Lots_New;                               // Exit user-defined function
  }
//========== FUNCTION Dynamic Lots

int DynamicLots()
  {

   if(EnableDynamicLots)
     {

      if(AccountBalance()>initialEquity+DynamicEquityUSD)
        {

         initialEquity=AccountBalance();

         if(old_dynamic_equity_lotsize<=v6_MAXLOTSIZE)
           {
            double new_dynamic_equity_lotsize=old_dynamic_equity_lotsize+DynamicEquityLots;

            LOTS=new_dynamic_equity_lotsize;

            dynamicFactor=new_dynamic_equity_lotsize/old_dynamic_equity_lotsize;

            old_dynamic_equity_lotsize=LOTS;

            CloseAtProfit=CloseAtProfit*dynamicFactor;
           }

        }
     }

   return 0;

  }
//========== FUNCTION whiteSpace

string Space()
  {

   return  "\n                                                                                                  "
   "                                                                                                    "
   "                                                                                                    ";

  }
//========== FUNCTION DisableGrid

int CloseGrid()
  {

   int total=OrdersTotal();

   for(int i=total-1;i>=0;i--)
     {
      OrderSelect(i,SELECT_BY_POS);
      int type=OrderType();

      int Profit=OrderProfit();

      if(Profit<0 || Profit>0 || OrderMagicNumber()!=MAGIC)continue;

      bool result=true;

      switch(type)
        {

         case OP_BUYSTOP   : result=OrderDelete(OrderTicket());
         break;

         case OP_SELLSTOP  : result=OrderDelete(OrderTicket());

        }

      if(result==false)
        {
         Alert("Order ",OrderTicket()," failed to close,CloseAllPending. Error:",GetLastError());
         Sleep(3000);
        }
     }
   return 0;
  }

//========== FUNCTION Indicators

double wpr,BolingerLowerBand,BolingerMidBand;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int BolingerAndWPR()
  {

   wpr=iWPR(

            Symbol(),// symbol
            TIMEFRAME,// timeframe
            14,// period
            1         // shift
            );

   BolingerLowerBand=iBands(

                            Symbol(),// symbol
                            TIMEFRAME,// timeframe
                            20,// averaging period
                            2,        // standard deviations
                            0,        // bands shift
                            PRICE_CLOSE,// applied price
                            MODE_LOWER,// line index
                            0         // shift

                            );

   BolingerMidBand=iBands(

                          Symbol(),// symbol
                          TIMEFRAME,// timeframe
                          20,// averaging period
                          2,        // standard deviations
                          0,        // bands shift
                          PRICE_CLOSE,// applied price
                          MODE_MAIN,// line index
                          0         // shift

                          );

   return 0;

  }
//========== FUNCTION set Grid

int CheckBuyGrid()
  {

   int total=OrdersTotal();

   for(int cpt=1;cpt<=LEVELS;cpt++)
     {
      bool foundbuy=false;

      for(int i=total-1;i>=0;i--)
        {

         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
           {

            if((OrderType()==OP_BUYSTOP || OrderType()==OP_BUY)
               && OrderOpenPrice()==NormalizeDouble(LowerLimit+cpt*INCREMENT*Point,Digits)
               || OrderTakeProfit()==NormalizeDouble(LowerLimit+cpt*INCREMENT*Point+INCREMENT*Point,Digits))
              {

               foundbuy=true;

              }

           }
        }

      if(!foundbuy && NormalizeDouble(LowerLimit+cpt*INCREMENT*Point,Digits)>Ask+(INCREMENT+StopLevel)*Point)
        {

         ticket=OrderSend(

                          Symbol()
                          ,OP_BUYSTOP
                          ,LOTS
                          ,NormalizeDouble(LowerLimit+cpt*INCREMENT*Point,Digits)
                          ,2
                          ,0//NormalizeDouble(Bid-STOPLOSS*Point,Digits)
                          ,0//NormalizeDouble(LowerLimit+cpt*INCREMENT*Point+INCREMENT*Point,Digits)
                          ,DoubleToStr(Ask,MarketInfo(Symbol(),MODE_DIGITS))
                          ,MAGIC
                          ,0

                          );
         if(ticket>0)
           {
            lastTradeTime=Time[THIS_BAR];
            if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) Print("BUYSTOP order opened : ",OrderOpenPrice());
           }
         else Print("Error opening BUYSTOP order : ",GetLastError());
        }

     }

   return 0;
  }
//========== FUNCTION Close Pending Orders

int CloseAllPending()
  {

   int total=OrdersTotal();

   for(int i=total-1;i>=0;i--)
     {
      OrderSelect(i,SELECT_BY_POS);
      int type=OrderType();

      int Profit=OrderProfit();

      if(Profit<0 || Profit>0 || OrderMagicNumber()!=1000)continue;

      bool result=true;

      switch(type)
        {

         case OP_BUYSTOP   : result=OrderDelete(OrderTicket());
         break;

         case OP_SELLSTOP  : result=OrderDelete(OrderTicket());

        }

      if(result==false)
        {
         Alert("Order ",OrderTicket()," failed to close,CloseAllPending. Error:",GetLastError());
         Sleep(3000);
        }
     }
   return 0;
  }
//========== FUNCTION CloseAll 

bool EndSession()
  {

   int cpt,total=OrdersTotal();

   for(cpt=0;cpt<total;cpt++)
     {
      //Sleep(3000);
      OrderSelect(cpt,SELECT_BY_POS);
      if(OrderSymbol()==Symbol() && OrderType()==OP_BUY && OrderProfit() > 0) OrderClose(OrderTicket(),OrderLots(),Bid,3);
      if(OrderSymbol()==Symbol() && OrderType()==OP_SELL && OrderProfit() > 0) OrderClose(OrderTicket(),OrderLots(),Ask,3);

     }

   for(cpt=0;cpt<total;cpt++)
     {
      //Sleep(3000);
      OrderSelect(cpt,SELECT_BY_POS);
      if(OrderSymbol()==Symbol() && OrderType()==OP_BUY && OrderMagicNumber()==MAGIC) OrderClose(OrderTicket(),OrderLots(),Bid,3);

     }

   for(cpt=0;cpt<total;cpt++)
     {
      //Sleep(3000);
      OrderSelect(cpt,SELECT_BY_POS);
      if(OrderSymbol()==Symbol() && OrderType()>1 ) OrderDelete(OrderTicket());
      if(OrderSymbol()==Symbol() && OrderType()==OP_BUY) OrderClose(OrderTicket(),OrderLots(),Bid,3);
      if(OrderSymbol()==Symbol() && OrderType()==OP_SELL) OrderClose(OrderTicket(),OrderLots(),Ask,3);

     }

   return(true);
  }
//========== FUNCTION PrintStats

void PrintStats()
  {
   int y,total;

   Tally      =0;
   LOrds      =0;
   SOrds      =0;
   PendBuy    =0;
   PendSell   =0;
   TSwap      =0;

   total=OrdersTotal();

   for(y=0;y<total;y++)
     {
      OrderSelect(y,SELECT_BY_POS);
      if(OrderSymbol()==Symbol())
        {

         if(OrderType()==OP_BUY)
           {
            LOrds++;
            Tally=Tally+OrderProfit();
            TSwap=TSwap + OrderSwap();

           }
         if(OrderType()==OP_SELL)
           {
            SOrds++;
            Tally=Tally+OrderProfit();
            TSwap=TSwap + OrderSwap();

           }
         if(OrderType()==OP_SELLSTOP)
           {
            PendSell++;

           }
         if(OrderType()==OP_BUYSTOP)
           {
            PendBuy++;

           }

        }//Symbol
     }//for loop

//  Comment("Float: ",Tally," Longs: ",LOrds," Shorts: ",SOrds);

  }//void
