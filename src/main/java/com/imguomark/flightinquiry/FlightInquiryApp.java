package com.imguomark.flightinquiry;

import javax.swing.*;
import javax.swing.border.EmptyBorder;
import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.Font;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class FlightInquiryApp {
  private final JTextField origin = new JTextField("SFO", 5);
  private final JTextField destination = new JTextField("PVG", 5);
  private final JTextArea results = new JTextArea();
  private final JLabel status = new JLabel("Enter a route and search for live aircraft activity.");
  private final HttpClient client = HttpClient.newHttpClient();
  public static void main(String[] args) { SwingUtilities.invokeLater(() -> new FlightInquiryApp().showWindow()); }
  private void showWindow() {
    JFrame frame = new JFrame("Flight Inquiry"); frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE); frame.setMinimumSize(new Dimension(720, 520));
    JPanel root = new JPanel(new BorderLayout(12, 12)); root.setBorder(new EmptyBorder(22, 22, 22, 22));
    JLabel title = new JLabel("Find live aircraft activity"); title.setFont(title.getFont().deriveFont(Font.BOLD, 26f));
    JPanel header = new JPanel(new BorderLayout(4, 4)); header.add(title, BorderLayout.NORTH); header.add(new JLabel("OpenSky state data only; ticket prices are not shown."), BorderLayout.SOUTH); root.add(header, BorderLayout.NORTH);
    JPanel search = new JPanel(new FlowLayout(FlowLayout.LEFT)); search.add(new JLabel("From")); search.add(origin); search.add(new JLabel("To")); search.add(destination); JButton go = new JButton("Search"); search.add(go);
    JPanel content = new JPanel(new BorderLayout(8, 8)); content.add(search, BorderLayout.NORTH); results.setEditable(false); results.setFont(new Font(Font.MONOSPACED, Font.PLAIN, 13)); content.add(new JScrollPane(results), BorderLayout.CENTER); root.add(content, BorderLayout.CENTER); root.add(status, BorderLayout.SOUTH);
    go.addActionListener(e -> search(go)); frame.setContentPane(root); frame.pack(); frame.setLocationByPlatform(true); frame.setVisible(true);
  }
  private void search(JButton go) {
    String from = origin.getText().trim().toUpperCase(Locale.ROOT), to = destination.getText().trim().toUpperCase(Locale.ROOT);
    if (!from.matches("[A-Z]{3}") || !to.matches("[A-Z]{3}")) { status.setText("Use three-letter airport codes."); return; }
    go.setEnabled(false); status.setText("Searching OpenSky...");
    new SwingWorker<List<Flight>, Void>() { protected List<Flight> doInBackground() throws Exception { return "true".equalsIgnoreCase(System.getenv("FLIGHT_INQUIRY_MOCK")) ? mock(from, to) : openSky(); } protected void done() { go.setEnabled(true); try { render(get(), from, to); } catch (Exception e) { status.setText("Search failed: " + message(e)); } } }.execute();
  }
  private List<Flight> openSky() throws Exception {
    HttpRequest request = HttpRequest.newBuilder(URI.create("https://opensky-network.org/api/states/all")).timeout(Duration.ofSeconds(20)).GET().build(); HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
    if (response.statusCode() < 200 || response.statusCode() >= 300) throw new IllegalStateException("OpenSky HTTP " + response.statusCode());
    List<Flight> flights = new ArrayList<>(); Matcher matcher = Pattern.compile("\\[\\s*\\\"([^\\\"]*)\\\"\\s*,\\s*\\\"([^\\\"]*)\\\"").matcher(response.body());
    while (matcher.find() && flights.size() < 40) flights.add(new Flight(matcher.group(1), matcher.group(2), "Live aircraft state")); return flights;
  }
  private List<Flight> mock(String from, String to) { return List.of(new Flight("MOCK-" + from + to + "-1", "Demo carrier", "Offline route-aware result"), new Flight("MOCK-" + from + to + "-2", "Demo carrier", "Generated for " + from + " to " + to)); }
  private void render(List<Flight> flights, String from, String to) { if (flights.isEmpty()) { status.setText("No aircraft activity returned. OpenSky is not a schedule API."); results.setText("No results.\\n"); return; } status.setText(flights.size() + " aircraft records returned; route matching is not guaranteed."); StringBuilder text = new StringBuilder("Route: ").append(from).append(" -> ").append(to).append("\\n\\n"); for (Flight flight : flights) text.append(String.format("%-20s %-26s %s%n", flight.id, flight.airline, flight.detail)); results.setText(text.toString()); }
  private static String message(Exception error) { Throwable t = error; while (t.getCause() != null) t = t.getCause(); return t.getMessage() == null ? t.toString() : t.getMessage(); }
  private record Flight(String id, String airline, String detail) {}
}
