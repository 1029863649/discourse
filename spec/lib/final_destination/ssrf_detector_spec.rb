# frozen_string_literal: true

describe FinalDestination::SSRFDetector do
  describe "site setting parsing" do
    it "can parse the blocked_ip_blocks and allowed_internal_hosts settings when the delimiter is pipe" do
      SiteSetting.blocked_ip_blocks = "13.134.89.0/24|73.234.19.0/30\n"
      SiteSetting.allowed_internal_hosts = "awesomesauce.com\n|goodbye.net"

      expect(subject.blocked_ip_blocks).to eq(%w[13.134.89.0/24 73.234.19.0/30])
      expect(subject.allowed_internal_hosts).to eq(
        [
          "test.localhost", # Discourse.base_url
          "awesomesauce.com",
          "goodbye.net",
        ],
      )
    end

    it "can parse the blocked_ip_blocks and allowed_internal_hosts settings when the delimiter is newline" do
      SiteSetting.blocked_ip_blocks = "13.134.89.0/24\n73.234.19.0/30\n\n"
      SiteSetting.allowed_internal_hosts = "awesomesauce.com\n\ngoodbye.net\n\n"

      expect(subject.blocked_ip_blocks).to eq(%w[13.134.89.0/24 73.234.19.0/30])
      expect(subject.allowed_internal_hosts).to eq(
        [
          "test.localhost", # Discourse.base_url
          "awesomesauce.com",
          "goodbye.net",
        ],
      )
    end

    it "ignores invalid IP blocks" do
      SiteSetting.blocked_ip_blocks = "2001:abc:de::/48|notanip"
      expect(subject.blocked_ip_blocks).to eq(%w[2001:abc:de::/48])
    end
  end

  describe ".ip_allowed?" do
    it "returns false for blocked IPs" do
      SiteSetting.blocked_ip_blocks = "98.0.0.0/8|78.13.47.0/24|9001:82f3::/32"
      expect(subject.ip_allowed?("98.23.19.111")).to eq(false)
      expect(subject.ip_allowed?("9001:82f3:8873::3")).to eq(false)
    end

    it "returns false for standard internal IPs" do
      expect(subject.ip_allowed?("172.31.100.31")).to eq(false)
      expect(subject.ip_allowed?("fd02:77fa:ffea::f")).to eq(false)
    end
  end

  describe ".host_bypasses_checks?" do
    it "returns true for URLs when allowed_internal_hosts allows the host" do
      SiteSetting.allowed_internal_hosts = "allowedhost1.com|allowedhost2.com"
      expect(subject.host_bypasses_checks?("allowedhost1.com")).to eq(true)
      expect(subject.host_bypasses_checks?("allowedhost2.com")).to eq(true)
    end

    it "returns false for other hosts" do
      expect(subject.host_bypasses_checks?("otherhost.com")).to eq(false)
    end

    it "returns true for the base uri" do
      SiteSetting.force_hostname = "final-test.example.com"
      expect(subject.host_bypasses_checks?("final-test.example.com")).to eq(true)
    end

    it "returns true for the S3 CDN url" do
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_cdn_url = "https://s3.example.com"
      expect(subject.host_bypasses_checks?("s3.example.com")).to eq(true)
    end

    it "returns true for the CDN url" do
      GlobalSetting.stubs(:cdn_url).returns("https://cdn.example.com/discourse")
      expect(subject.host_bypasses_checks?("cdn.example.com")).to eq(true)
    end
  end

  describe ".lookup_and_filter_ips" do
    it "returns a fake response in tests" do
      expect(subject.lookup_and_filter_ips("example.com")).to eq(["1.2.3.4"])
    end

    it "correctly filters private and blocked IPs" do
      SiteSetting.blocked_ip_blocks = "9.10.11.12/24"
      subject.stubs(:lookup_ips).returns(%w[127.0.0.1 5.6.7.8 9.10.11.12])
      expect(subject.lookup_and_filter_ips("example.com")).to eq(["5.6.7.8"])
    end

    it "raises an exception if all IPs are blocked" do
      subject.stubs(:lookup_ips).returns(["127.0.0.1"])
      expect { subject.lookup_and_filter_ips("example.com") }.to raise_error(
        subject::DisallowedIpError,
      )
    end

    it "raises an exception if lookup fails" do
      subject.stubs(:lookup_ips).raises(SocketError)
      expect { subject.lookup_and_filter_ips("example.com") }.to raise_error(
        subject::LookupFailedError,
      )
    end

    it "bypasses filtering for allowlisted hosts" do
      SiteSetting.allowed_internal_hosts = "example.com"
      subject.stubs(:lookup_ips).returns(["127.0.0.1"])
      expect(subject.lookup_and_filter_ips("example.com")).to eq(["127.0.0.1"])
    end
  end
end
