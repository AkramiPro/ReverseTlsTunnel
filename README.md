# مقدمه
تونل معکوس که فکر میکنم باهاش آشنا باشید ؛ فرقش با تونل عادی اینه که کانکشن رو سرور خارج ایجاد میکنه مثل یک بازدید کننده خارجی از یه سایت ایرانی که سرور شما باشه
و بعد از اتصال ؛ دیتا مثل تونل عادی رد و بدل میشه ؛ این روش از تونل های عادی که سرور ایران به خارج کانکشن رو شروع میکنه از نظر دیتکت میشه گفت بهتره چون عموما یه سرور کانکشن به جایی شروع نمکنه (برای مدت طولانی و تعداد کانکشن همزمان بالا!)

البته هنوز سیستم فیلترینگی که در ایران هست به مرحله این گونه تشخیص ها نرسیده چون همونطور که میدونیم هنوز هم حتی iptable کار میکنه (بستگی به دیتا سنتر و ایپی خارج و هدر http و غیره...)

روش تونل معکوس مدت ها هست که استفاده میشه اولین بار من از طریق ssh اینو دیدم و بعد یک پروژه هم تو گیت هاب دیدم که این رو با node js پیاده کرده بود.

و خوب سعی کردم این پروژه صرفا یه کپی نباشه و مزیت هایی داشته باشه ؛ نمیخوام خیلی تخصصی توضیح بدم ولی به طور کلی فرقی که هست اینه که سرور خارج با سرور ایران با استفاده از دامنه یه سایت ایرانی هند شیک میکنه و بعد دیتا رد و بدل میشه درصورتی که تونل های معکوس دیگه هند شیک بدون دامنه صرفا با public key داشتن (تا جایی که میدونم) 

فرق دومی هم که داره اینه که این پروژه از قابلیت mux استفاده میکنه تا تعداد کانکشن های بین سرور ایران و خارج همیشه حاصل جمع کلاینت ها نباشه و خوب این نکته بولدی هست که باید انجام بشه ( نسخه ۱ هنوز این قابلیت توش فعال نیست ولی بدون مشکل کار میکنه چون سیستم فیلترینگ (واقعا نمیدونم چرا...) از این نکته برای تشخیص تونل ها استفاده نکرده که خب خداروشکر...

و فرق های جزعی دیگه که علاقه داشتین کد رو بخونین و به دلخواه تغییر بدین ؛ کد خوانا تر از faketlstunnel نوشته شده برای دوستانی که میخواستن تونل مخصوص خودشونو بنویسن


# نحوه استفاده 

وارد پوشه ی مورد نظرتون برای نصب برنامه بشید مثلا /root
و کلا برنامه یه فایل هست نصب خاصی نداره فقط فایل دانلود میشه توی همون مسیر که هستین و بهتره بوزر root باشین 

با این دستور برنامه رو دانلود کنید
```sh
wget  "https://raw.githubusercontent.com/radkesvat/ReverseTlsTunnel/master/install.sh" -O install.sh && chmod +x install.sh && bash install.sh 
```
