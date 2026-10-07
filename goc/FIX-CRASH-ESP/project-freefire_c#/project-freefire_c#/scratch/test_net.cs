using System;
using System.Net;

class TestNet {
    public static void Main() {
        try {
            string url = "http://103.238.234.204:2007/api/status";
            Console.WriteLine("URL: " + url);
        } catch (Exception ex) {
            Console.WriteLine("Error: " + ex.Message);
        }
    }
}
