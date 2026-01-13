using System;

namespace Backend.Data
{
    public static class TimeHelper
    {
        public static DateTime GetBaghdadTime()
        {
            // بغداد توقيت جرينتش +3
            return DateTime.UtcNow.AddHours(3);
        }
    }
}
